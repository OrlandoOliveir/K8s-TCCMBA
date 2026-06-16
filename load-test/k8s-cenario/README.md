# Kubernetes Scenario Load Test

Scripts for load testing the Kubernetes scenario.

## Requisitos

- kubectl configurado para o namespace `tcc`
- NodePort exposto em `localhost:30080`
- k6
- bash

## Estrutura

- `k6-script.js` — k6 load test script
- `fault-test.sh` — simula falha e mede recuperação enquanto gera carga
- `run-test.sh` — executa `fault-test.sh` e depois o teste de carga puro

## Como usar

```bash
cd load-test/k8s-cenario
./run-test.sh
```

Os resultados são gerados em `load-test/results/`:

- `load-test.json`
- `load-test-summary.json`
- `fault-recovery.txt`
- `health-monitor.log`
