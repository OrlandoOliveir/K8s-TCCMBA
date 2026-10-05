# Comparativo Docker vs Kubernetes

| Métrica | Cenário Docker | Cenário Kubernetes |
|---|---:|---:|
| Tempo médio de resposta (ms) | 5.04 | 4.54 |
| P95 do tempo de resposta (ms) | 7.40 | 6.11 |
| Requisições por segundo | 53.25 | 53.30 |
| Taxa de erro sob carga (%) | 0.00 | 0.00 |
| Taxa de erro durante a falha (%) | 0.90 | 0.00 |
| Tempo de recuperação após falha (ms) | 1900 | 1082 |
| Tempo de indisponibilidade (ms) | 1900 | 1082 |

_Tempo de recuperação e de indisponibilidade calculados a partir do `health-monitor.log` (amostragem a cada 200 ms): intervalo entre a primeira resposta inválida e a primeira resposta válida seguinte._

_Gerado em 2026-10-04 23:08:23 por `gerar-comparativo.sh`._
