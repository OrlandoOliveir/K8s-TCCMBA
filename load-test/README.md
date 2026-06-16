# Load Test Framework

Este workspace inclui dois cenários de teste para comparação científica:

- `load-test/docker-cenario/`
- `load-test/k8s-cenario/`

Cada cenário inclui:

- `k6-script.js` — script de carga para `k6`
- `fault-test.sh` — simula falha e mede recuperação/indisponibilidade
- `run-test.sh` — executa o cenário completo

## Resultados

Os resultados são gravados em `load-test/results/docker/` e `load-test/results/k8s/`:

- `load-test.json`
- `load-test-summary.json`
- `fault-load-test.json`
- `fault-load-test-summary.json`
- `fault-recovery.txt`
- `health-monitor.log`
