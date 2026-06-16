#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
RESULTS_DIR="$ROOT/results/docker"
mkdir -p "$RESULTS_DIR"

export BASE_URL="http://localhost:8080"

pushd "$ROOT/docker-cenario" >/dev/null
./fault-test.sh
if ! k6 run --summary-export "$RESULTS_DIR/load-test-summary.json" --out json="$RESULTS_DIR/load-test.json" k6-script.js; then
  echo "k6 load test failed. Check $RESULTS_DIR/load-test-summary.json and $RESULTS_DIR/load-test.json for details."
  popd >/dev/null
  exit 1
fi
popd >/dev/null

echo "Load test complete. Results in $RESULTS_DIR"
