#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
RESULTS_DIR="$ROOT/results/docker"
mkdir -p "$RESULTS_DIR"

TARGET_URL="http://localhost:8080/health"
MONITOR_LOG="$RESULTS_DIR/health-monitor.log"
FAULT_FILE="$RESULTS_DIR/fault-recovery.txt"
K6_LOG="$RESULTS_DIR/k6-fault.log"
K6_SUMMARY="$RESULTS_DIR/fault-load-test-summary.json"
K6_JSON="$RESULTS_DIR/fault-load-test.json"
TIMEOUT_SEC=120

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
  pushd "$ROOT/docker-cenario" >/dev/null
  k6 run --summary-export "$K6_SUMMARY" --out json="$K6_JSON" --vus 30 --duration 120s k6-script.js > "$K6_LOG" 2>&1 &
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
  echo "Running Docker fault recovery test..."

  start_monitor &
  MONITOR_PID=$!

  start_k6
  sleep 10

  echo "Simulating failure: stopping docker-compose services..."
  pushd "$ROOT/../1_cenario_docker" >/dev/null
  docker compose down
  popd >/dev/null

  failure_ns=$(date +%s%N)

  echo "Restarting docker-compose services..."
  pushd "$ROOT/../1_cenario_docker" >/dev/null
  docker compose up -d
  popd >/dev/null

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

  echo "recovery_seconds=$recovery_s" > "$FAULT_FILE"
  echo "downtime_milliseconds=$downtime_ms" >> "$FAULT_FILE"
  echo "failure_timestamp_ns=$failure_ns" >> "$FAULT_FILE"
  echo "recovery_timestamp_ns=${recovery_ns:-}" >> "$FAULT_FILE"

  kill_monitor

  echo "Restarting docker-compose services..."
  pushd "$ROOT/../1_cenario_docker" >/dev/null
  docker compose up -d
  popd >/dev/null

  echo "Fault recovery test complete. Results saved to $FAULT_FILE"
}

main "$@"
