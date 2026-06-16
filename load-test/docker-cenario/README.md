# Docker Scenario Load Test

Scripts for load testing the Docker scenario.

## Requisitos

- Docker Compose
- k6
- bash

## Estrutura

- `k6-script.js` — k6 load test script
- `fault-test.sh` — simula falha e mede recuperação
- `run-test.sh` — executa `fault-test.sh` e depois o teste de carga

## Como usar

```bash
cd load-test/docker-cenario
./run-test.sh
```

Os resultados são gerados em `load-test/results/`:

- `load-test.json`
- `load-test-summary.json`
- `fault-recovery.txt`
- `health-monitor.log`
