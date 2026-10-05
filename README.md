# TCC — Docker vs Kubernetes: Análise Comparativa de Desempenho e Resiliência

Trabalho de Conclusão de Curso (MBA em Engenharia de Software) que compara, de forma reproduzível, o comportamento de uma mesma aplicação web executada em dois ambientes distintos: **Docker Compose** (sem orquestração) e **Kubernetes** (via kind).

**Título do trabalho:** Kubernetes como plataforma padrão para orquestração de aplicações: impactos na arquitetura de software moderna.

---

## Visão geral

A aplicação é uma API REST em PHP/Nginx conectada a um banco MySQL. O mesmo código-fonte é utilizado nos dois cenários; o que muda é exclusivamente a camada de infraestrutura. Testes de carga automatizados com k6 medem desempenho e resiliência a falhas em cada ambiente.

Para manter a paridade entre os cenários, o Deployment da aplicação no Kubernetes utiliza **uma única réplica**, equivalente ao único container da aplicação no cenário Docker. Assim, a comparação avalia o efeito da orquestração, e não o da redundância de instâncias.

---

## Estrutura do repositório

```
.
├── 1_cenario_docker/          # Cenário 1 — Docker Compose
│   ├── app/                   # Código-fonte da aplicação (PHP + Nginx)
│   │   ├── Dockerfile
│   │   ├── index.php
│   │   ├── nginx.conf
│   │   ├── start.sh
│   │   └── repositories/
│   │       ├── Database.php
│   │       └── ClientRepository.php
│   ├── db/
│   │   └── init.sql           # Script de inicialização do banco
│   └── docker-compose.yml
│
├── 2_cenario_k8s/             # Cenário 2 — Kubernetes (kind)
│   ├── app/                   # Mesmo código-fonte do cenário Docker
│   └── k8s/                   # Manifestos e scripts Kubernetes
│       ├── namespace.yaml
│       ├── resourcequota.yaml
│       ├── mysql-configmap.yaml
│       ├── mysql-deployment.yaml
│       ├── app-deployment.yaml
│       ├── build-and-load-kind.sh
│       ├── apply-kind.sh
│       └── delete-kind.sh
│
└── load-test/                 # Testes de carga e falha
    ├── docker-cenario/
    │   ├── k6-script.js       # Script k6 de carga normal
    │   ├── fault-test.sh      # Teste de falha + monitoramento
    │   └── run-test.sh        # Executa falha, carga e gera o comparativo
    ├── k8s-cenario/
    │   ├── k6-script.js
    │   ├── fault-test.sh
    │   └── run-test.sh
    ├── gerar-comparativo.sh   # Gera o comparativo.md a partir dos resultados
    ├── results/               # Gerado após execução (não versionado)
    │   ├── docker/
    │   └── k8s/
    └── comparativo.md         # Tabela de resultados gerada automaticamente
```

---

## Aplicação

### Endpoints

| Método | Rota | Descrição |
|---|---|---|
| `GET` | `/health` | Health check — retorna status, hostname e timestamp |
| `GET` | `/clients` | Lista todos os clientes cadastrados no banco |
| `GET` | `/client?id=X` | Retorna um cliente pelo ID |

### Stack

| Componente | Versão |
|---|---|
| PHP / PHP-FPM | 8.0 (Alpine) |
| Nginx | 1.25 |
| MySQL | 8.0 |
| k6 | v2.0.0 |

- **Infraestrutura — Cenário 1:** Docker Compose, aplicação em `localhost:8080`
- **Infraestrutura — Cenário 2:** Kubernetes (kind), namespace `tcc`, NodePort 30080

---

## Ambiente experimental

Os dois cenários foram executados com os mesmos recursos de máquina:

| Recurso | Cenário 1 (Docker) | Cenário 2 (Kubernetes) |
|---|---|---|
| vCPUs | 2 | 2 |
| Memória RAM | 4 GB | 4 GB |
| Armazenamento | 20 GB | 20 GB |
| Sistema operacional | Ubuntu 26.04 LTS | Ubuntu 26.04 LTS |
| Docker | v29.5.3 | v29.5.3 |
| Kubernetes | — | v1.36.2 |
| kind | — | v0.32.0 |

---

## Pré-requisitos

| Ferramenta | Cenário Docker | Cenário K8s |
|---|:---:|:---:|
| Docker + Docker Compose | Obrigatório | Obrigatório (build da imagem) |
| kind | — | Obrigatório |
| kubectl | — | Obrigatório |
| k6 | Obrigatório | Obrigatório |
| jq | Obrigatório | Obrigatório |
| python3 | — | Obrigatório |
| curl, awk, bash | Obrigatório | Obrigatório |

---

## Cenário 1 — Docker Compose

### Subir a aplicação

```bash
cd 1_cenario_docker
docker compose up --build -d
```

A aplicação ficará disponível em `http://localhost:8080`.

### Verificar

```bash
curl http://localhost:8080/health
curl http://localhost:8080/clients
```

### Derrubar

```bash
docker compose down
```

---

## Cenário 2 — Kubernetes (kind)

### 1. Criar o cluster kind

```bash
kind create cluster --name kind
```

### 2. Build e carga da imagem no kind

```bash
cd 2_cenario_k8s/k8s
./build-and-load-kind.sh kind 1_cenario_docker-app:latest
```

### 3. Aplicar os manifestos

```bash
./apply-kind.sh
```

O script aplica o namespace, o ConfigMap de inicialização do banco e os Deployments/Services do MySQL e da aplicação, e aguarda o rollout de `mysql` e `tcc-app`.

### 4. Verificar

```bash
curl http://localhost:30080/health
curl http://localhost:30080/clients
```

> Se a aplicação não responder em `localhost:30080`, os scripts de teste tentam automaticamente o IP interno do nó do kind.

### Remover os recursos

```bash
./delete-kind.sh
```

---

## Testes

Os testes utilizam [k6](https://k6.io). Em cada cenário, o `run-test.sh` executa, em sequência, o teste de falha, o teste de carga normal e, por fim, o `gerar-comparativo.sh`.

### Teste de carga normal (`k6-script.js`)

Simula um aumento progressivo de usuários virtuais (VUs) contra o endpoint `/clients`:

| Fase | Duração | VUs |
|---|---|---|
| Rampa de subida | 30 s | 0 → 20 |
| Carga sustentada | 60 s | 20 → 50 |
| Pico | 120 s | 50 → 100 |
| Rampa de descida | 30 s | 100 → 0 |

**Thresholds:** P95 < 1000 ms, taxa de erro < 1%.

### Teste de falha (`fault-test.sh`)

Executa 30 VUs por 120 s e, após 10 s de aquecimento, provoca uma falha:

- **Docker:** `docker compose stop app` seguido de `docker compose start app` (reinício por comando externo)
- **Kubernetes:** `kubectl delete pod -l app=tcc-app -n tcc --grace-period=0 --force` (recriação automática pelo Deployment)

Durante todo o teste, o endpoint `/health` é monitorado a cada 200 ms, e cada resposta é registrada com timestamp e código HTTP no `health-monitor.log`.

### Como as métricas são calculadas

| Métrica | Origem |
|---|---|
| Tempo médio de resposta, P95, req/s, taxa de erro sob carga | `load-test-summary.json` (teste de carga normal) |
| Taxa de erro durante a falha | `fault-load-test-summary.json` (teste de falha) |
| Tempo de recuperação e de indisponibilidade | `health-monitor.log`: intervalo entre a primeira resposta inválida e a primeira resposta válida seguinte (resolução de 200 ms) |

Como o tempo de recuperação e o de indisponibilidade são calculados pelo mesmo intervalo observado no monitoramento, as duas métricas apresentam o mesmo valor.

### Executar os testes

**Cenário Docker** — com a aplicação já rodando (`docker compose up -d`):

```bash
cd load-test/docker-cenario
./run-test.sh
```

**Cenário K8s** — com o cluster kind e os manifestos já aplicados:

```bash
cd load-test/k8s-cenario
./run-test.sh
```

Os resultados são gravados em `load-test/results/docker/` e `load-test/results/k8s/`, e o `load-test/comparativo.md` é atualizado ao final. Para regenerar o comparativo a partir de resultados já existentes, sem executar os testes novamente:

```bash
cd load-test
./gerar-comparativo.sh
```

---

## Resultados obtidos

| Métrica | Docker | Kubernetes |
|---|---:|---:|
| Tempo médio de resposta | 5,04 ms | 4,54 ms |
| P95 do tempo de resposta | 7,40 ms | 6,11 ms |
| Requisições por segundo | 53,25 req/s | 53,30 req/s |
| Taxa de erro sob carga | 0% | 0% |
| Taxa de erro durante a falha | 0,90% | 0% |
| Tempo de recuperação após falha | 1,9 s | 1,08 s |
| Tempo de indisponibilidade | 1,9 s | 1,08 s |

> Valores gerados em [`load-test/comparativo.md`](load-test/comparativo.md).

### Esforço de configuração e operação

| Critério | Docker | Kubernetes |
|---|---:|---:|
| Arquivos declarativos | 1 | 5 |
| Linhas declarativas (LOC) | 49 | 169 (139 sem SQL) |
| Objetos/recursos declarados | 3 | 8 |
| Comandos para provisionar o ambiente | 1 | 3 |
| Intervenções manuais para recuperar após falha | 1 | 0 |
| Tempo de provisionamento (média de 5 execuções) | 16,28 s | 22,68 s |

---

## Observações sobre os resultados

- **Carga normal:** os dois ambientes apresentaram desempenho praticamente equivalente, com diferenças inferiores a 1 ms no tempo médio e no P95.
- **Resiliência a falhas:** no Docker, o serviço ficou cerca de 1,9 s indisponível, 0,90% das requisições falharam e a recuperação dependeu de um comando externo. No Kubernetes, a indisponibilidade observada foi de cerca de 1,1 s (aproximadamente 43% menor), nenhuma requisição do k6 falhou e o Pod foi recriado automaticamente pelo Deployment.
- **Ausência de erros no Kubernetes:** apesar da breve indisponibilidade registrada pelo monitoramento, o k6 não registrou erros, o que sugere que parte das requisições foi retardada durante a recriação do Pod, em vez de rejeitada.
- **Configuração:** o Kubernetes exigiu mais arquivos, linhas e etapas de provisionamento, mas reduziu o esforço de operação ao assumir a recuperação da aplicação.

### Limitações

- O experimento foi executado em ambiente local controlado e não representa integralmente ambientes corporativos de produção.
- O Deployment foi configurado com uma única réplica, para manter a paridade com o cenário Docker. Testes com múltiplas réplicas e verificações de prontidão (`readinessProbe`) podem avaliar se a indisponibilidade no Kubernetes pode ser eliminada.
- A resolução do monitoramento é de 200 ms, o que limita a precisão dos tempos de recuperação e de indisponibilidade.
