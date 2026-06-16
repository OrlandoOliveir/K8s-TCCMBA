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

_KUBECONFIG_TMP=""
if [[ -z "${KUBECONFIG:-}" ]]; then
  _KUBECONFIG_TMP=$(mktemp /tmp/kind-kubeconfig-XXXXXX.yaml)
  kind get kubeconfig --name "$KIND_CLUSTER" > "$_KUBECONFIG_TMP"
  KUBECONFIG="$_KUBECONFIG_TMP"
  trap 'rm -f "$_KUBECONFIG_TMP"' EXIT
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
  return 1
}

BASE_URL=$(resolve_k8s_base_url)
export BASE_URL

pushd "$ROOT/k8s-cenario" >/dev/null
./fault-test.sh
preflight_check() {
  local tries=0
  local max=10
  echo "Preflight: checking $BASE_URL/health and $BASE_URL/clients"
  until curl -fsS "$BASE_URL/health" >/dev/null 2>&1 && curl -fsS "$BASE_URL/clients" >/dev/null 2>&1; do
    tries=$((tries+1))
    if (( tries >= max )); then
      echo "Preflight failed: service not responding after $max attempts" >&2
      return 1
    fi
    echo "  waiting for service... attempt $tries/$max"
    sleep 1
  done
  echo "Preflight OK"
}

validate_p95() {
  local summary="$RESULTS_DIR/load-test-summary.json"
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
      echo "ERROR: exported summary has p95=0 or missing ($summary)" >&2
      return 1
    fi
  fi
  return 0
}

if ! preflight_check; then
  echo "Preflight failed, aborting k6 run." >&2
  popd >/dev/null
  exit 1
fi

if ! k6 run --summary-export "$RESULTS_DIR/load-test-summary.json" --out json="$RESULTS_DIR/load-test.json" k6-script.js; then
  echo "k6 load test failed. Check $RESULTS_DIR/load-test-summary.json and $RESULTS_DIR/load-test.json for details."
  popd >/dev/null
  exit 1
fi
if ! validate_p95; then
  echo "k6 reported invalid p95; check $RESULTS_DIR/load-test-summary.json" >&2
  popd >/dev/null
  exit 1
fi
popd >/dev/null

echo "Load test complete. Results in $RESULTS_DIR"
