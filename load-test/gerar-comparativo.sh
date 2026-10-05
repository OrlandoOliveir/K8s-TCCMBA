#!/usr/bin/env bash
# Gera load-test/comparativo.md a partir dos resultados em results/docker e results/k8s.
set -euo pipefail
export LC_NUMERIC=C

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT="$ROOT/comparativo.md"

# Lê uma métrica do summary do k6 (jq path); imprime "-" se o arquivo/métrica não existir.
k6_metric() {
  local summary=$1 path=$2 fmt=$3
  if [[ -f "$summary" ]]; then
    local v
    v=$(jq -r "$path // empty" "$summary" 2>/dev/null || true)
    if [[ -n "$v" ]]; then
      printf "$fmt" "$v"
      return
    fi
  fi
  printf -- "-"
}

# Lê chave=valor do fault-recovery.txt; aceita vírgula decimal de execuções antigas.
fault_value() {
  local file=$1 key=$2
  if [[ -f "$file" ]]; then
    local v
    v=$(grep -E "^$key=" "$file" | cut -d= -f2 | tr ',' '.')
    if [[ -n "$v" ]]; then
      echo "$v"
      return
    fi
  fi
  echo "-"
}

row() {
  local label=$1 docker=$2 k8s=$3
  echo "| $label | $docker | $k8s |"
}

D="$ROOT/results/docker"
K="$ROOT/results/k8s"

{
  echo "# Comparativo Docker vs Kubernetes"
  echo
  echo "| Métrica | Cenário Docker | Cenário Kubernetes |"
  echo "|---|---:|---:|"
  row "Tempo médio de resposta (ms)" \
    "$(k6_metric "$D/load-test-summary.json" '.metrics.http_req_duration.avg' '%.2f')" \
    "$(k6_metric "$K/load-test-summary.json" '.metrics.http_req_duration.avg' '%.2f')"
  row "P95 do tempo de resposta (ms)" \
    "$(k6_metric "$D/load-test-summary.json" '.metrics.http_req_duration["p(95)"]' '%.2f')" \
    "$(k6_metric "$K/load-test-summary.json" '.metrics.http_req_duration["p(95)"]' '%.2f')"
  row "Requisições por segundo" \
    "$(k6_metric "$D/load-test-summary.json" '.metrics.http_reqs.rate' '%.2f')" \
    "$(k6_metric "$K/load-test-summary.json" '.metrics.http_reqs.rate' '%.2f')"
  row "Taxa de erro sob carga (%)" \
    "$(k6_metric "$D/load-test-summary.json" '.metrics.http_req_failed.value * 100' '%.2f')" \
    "$(k6_metric "$K/load-test-summary.json" '.metrics.http_req_failed.value * 100' '%.2f')"
  row "Taxa de erro durante a falha (%)" \
    "$(k6_metric "$D/fault-load-test-summary.json" '.metrics.http_req_failed.value * 100' '%.2f')" \
    "$(k6_metric "$K/fault-load-test-summary.json" '.metrics.http_req_failed.value * 100' '%.2f')"
  row "Tempo de recuperação após falha (s)" \
    "$(fault_value "$D/fault-recovery.txt" recovery_seconds)" \
    "$(fault_value "$K/fault-recovery.txt" recovery_seconds)"
  row "Tempo de indisponibilidade (ms)" \
    "$(fault_value "$D/fault-recovery.txt" downtime_milliseconds)" \
    "$(fault_value "$K/fault-recovery.txt" downtime_milliseconds)"
  echo
  echo "_Gerado em $(date '+%Y-%m-%d %H:%M:%S') por \`gerar-comparativo.sh\`._"
} > "$OUT"

echo "Comparativo atualizado em $OUT"
