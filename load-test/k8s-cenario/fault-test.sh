#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
RESULTS_DIR="$ROOT/results/k8s"
mkdir -p "$RESULTS_DIR"

KIND_CLUSTER=${KIND_CLUSTER:-$(kind get clusters | head -n1)}
if [[ -z "$KIND_CLUSTER" ]]; then
  echo "Error: no kind cluster found. Set KIND_CLUSTER or create a kind cluster." >&2
  exit 1
fi

if [[ -z "${KUBECONFIG:-}" ]]; then
  KUBECONFIG=$(kind get kubeconfig --name "$KIND_CLUSTER")
fi
export KUBECONFIG

resolve_k8s_base_url() {
  local port
  port=$(kubectl -n tcc get svc app -o jsonpath='{.spec.ports[0].nodePort}')

  if curl -fsS "http://localhost:$port/health" >/dev/null 2>&1; then
    echo "http://localhost:$port"
    return 0
  fi

  local node_name node_ip
  node_name=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
  node_ip=$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
  if [[ -n "$node_ip" ]] && curl -fsS "http://$node_ip:$port/health" >/dev/null 2>&1; then
    echo "http://$node_ip:$port"
    return 0
  fi

  echo "Error: could not reach Kubernetes app service on localhost:$port or $node_ip:$port" >&2
  exit 1
}

BASE_URL=$(resolve_k8s_base_url)
TARGET_URL="$BASE_URL/health"
MONITOR_LOG="$RESULTS_DIR/health-monitor.log"
FAULT_FILE="$RESULTS_DIR/fault-recovery.txt"
K6_LOG="$RESULTS_DIR/k6-fault.log"
K6_SCRIPT="$ROOT/k8s-cenario/k6-script.js"
K6_SUMMARY="$RESULTS_DIR/fault-load-test-summary.json"
K6_JSON="$RESULTS_DIR/fault-load-test.json"
TIMEOUT_SEC=120

preflight_check() {
  local tries=0 max=10
  echo "Preflight: checking $BASE_URL/health"
  until curl -fsS "$BASE_URL/health" >/dev/null 2>&1; do
    tries=$((tries+1))
    if (( tries >= max )); then
      echo "Preflight failed: service not responding after $max attempts" >&2
      return 1
    fi
    sleep 1
  done
  return 0
}

validate_p95_failure() {
  local summary="$K6_SUMMARY"
  if [[ -f "$summary" ]]; then
    p95=$(python3 - <<PY
import json,sys
try:
    d=json.load(open('$summary'))
    p=d.get('metrics',{}).get('http_req_duration',{}).get('p(95)',0)
    print(p)
except Exception:
    print(0)
    sys.exit(0)
PY
)
    if [[ "$p95" == "0" || -z "$p95" ]]; then
      echo "WARNING: fault test summary p95=0 or missing ($summary)" >&2
      return 1
    fi
  fi
  return 0
}

trap 'kill_monitor' EXIT

start_monitor() {
  echo "timestamp_ns,http_status" > "$MONITOR_LOG"
  while true; do
    status=$(curl -s -o /dev/null -w '%{http_code}' "$TARGET_URL" || echo 000)
    echo "$(date +%s%N),$status" >> "$MONITOR_LOG"
    sleep 0.2
  done
}

kill_monitor() {
  if [[ -n "${MONITOR_PID:-}" ]]; then
    kill "$MONITOR_PID" 2>/dev/null || true
    wait "$MONITOR_PID" 2>/dev/null || true
  fi
}

start_k6() {
  pushd "$ROOT/k8s-cenario" >/dev/null
  k6 run --summary-export "$K6_SUMMARY" --out json="$K6_JSON" --vus 30 --duration 120s "$K6_SCRIPT" > "$K6_LOG" 2>&1 &
  K6_PID=$!
  popd >/dev/null
}

measure_recovery() {
  local start_ns=$1
  local deadline=$((start_ns + TIMEOUT_SEC * 1000000000))

  while true; do
    now_ns=$(date +%s%N)
    if (( now_ns >= deadline )); then
      echo "timeout"
      return 1
    fi

    status=$(curl -s -o /dev/null -w '%{http_code}' "$TARGET_URL" || echo 000)
    if [[ "$status" == "200" ]]; then
      echo "$now_ns"
      return 0
    fi
    sleep 0.2
  done
}

main() {
  echo "Running Kubernetes fault recovery test..."

  start_monitor &
  MONITOR_PID=$!

  if ! preflight_check; then
    echo "Preflight failed for fault test, aborting." >&2
    kill_monitor
    exit 1
  fi

  start_k6
  sleep 10

  echo "Simulating failure: deleting app pod..."
  kubectl delete pod -l app=tcc-app -n tcc --grace-period=0 --force

  failure_ns=$(date +%s%N)

  echo "Waiting for service recovery..."
  if recovery_ns=$(measure_recovery "$failure_ns"); then
    recovery_s=$(awk "BEGIN {print ($recovery_ns - $failure_ns) / 1000000000}")
    downtime_ms=$(( (recovery_ns - failure_ns) / 1000000 ))
  else
    recovery_s="timeout"
    downtime_ms=$((TIMEOUT_SEC * 1000))
  fi

  if [[ -n "${K6_PID:-}" ]]; then
    if ! wait "$K6_PID"; then
      K6_EXIT_CODE=$?
    fi
  fi

  if [[ "${K6_EXIT_CODE:-0}" -ne 0 ]]; then
    echo "k6 fault test failed with exit code $K6_EXIT_CODE. Check $K6_LOG, $K6_SUMMARY, and $K6_JSON."
  fi

  # Validate p95 for fault run (warn if invalid)
  validate_p95_failure || echo "Fault test p95 looks invalid; investigate $K6_SUMMARY"

  echo "recovery_seconds=$recovery_s" > "$FAULT_FILE"
  echo "downtime_milliseconds=$downtime_ms" >> "$FAULT_FILE"
  echo "failure_timestamp_ns=$failure_ns" >> "$FAULT_FILE"
  echo "recovery_timestamp_ns=${recovery_ns:-}" >> "$FAULT_FILE"

  kill_monitor

  echo "Fault recovery test complete. Results saved to $FAULT_FILE"
}

main "$@"
