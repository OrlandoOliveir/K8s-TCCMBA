# TCC — Docker vs Kubernetes: Análise Comparativa de Desempenho e Resiliência

Trabalho de Conclusão de Curso que compara, de forma científica e reproduzível, o comportamento de uma mesma aplicação web executada em dois ambientes distintos: **Docker Compose** (sem orquestração) e **Kubernetes** (via kind).

---

## Visão geral

A aplicação é uma API REST em PHP/Nginx conectada a um banco MySQL. O mesmo código-fonte é utilizado nos dois cenários; o que muda é exclusivamente a camada de infraestrutura. Testes de carga automatizados com k6 medem desempenho e resiliência a falhas em cada ambiente.

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
└── load-test/                 # Testes de carga
    ├── docker-cenario/
    │   ├── k6-script.js       # Script k6
    │   ├── fault-test.sh      # Teste de falha + recuperação
    │   └── run-test.sh        # Orquestrador: executa fault + carga
    ├── k8s-cenario/
    │   ├── k6-script.js
    │   ├── fault-test.sh
    │   └── run-test.sh
    ├── results/               # Gerado após execução (não versionado)
    │   ├── docker/
    │   └── k8s/
    └── comparativo.md         # Tabela de resultados preenchida
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

- **Runtime:** PHP-FPM + Nginx
- **Banco de dados:** MySQL 8.0
- **Infraestrutura — Cenário 1:** Docker Compose
- **Infraestrutura — Cenário 2:** Kubernetes (kind), namespace `tcc`, NodePort 30080

---

## Pré-requisitos

| Ferramenta | Cenário Docker | Cenário K8s |
|---|:---:|:---:|
| Docker + Docker Compose | Obrigatório | Obrigatório (build da imagem) |
| kind | — | Obrigatório |
| kubectl | — | Obrigatório |
| k6 | Obrigatório | Obrigatório |
| python3 | Obrigatório | Obrigatório |
| curl, bash | Obrigatório | Obrigatório |

---

## Cenário 1 — Docker Compose

### Especificações do ambiente

| Recurso | Valor |
|---|---|
| vCPUs | 2 |
| Memória RAM | 4 GB |
| Armazenamento | 20 GB |
| Sistema operacional | Ubuntu 24.04 LTS |
| Docker | v29.5.3 |

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

### Especificações do ambiente

| Recurso | Valor |
|---|---|
| vCPUs | 2 |
| Memória RAM | 4 GB |
| Armazenamento | 20 GB |
| Sistema operacional | Ubuntu 24.04 LTS |
| kind | local cluster |
| Namespace | `tcc` |
| NodePort | 30080 |

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

O script aplica todos os manifestos e aguarda o rollout dos deployments (`mysql` e `tcc-app`).

### 4. Verificar

```bash
curl http://localhost:30080/health
curl http://localhost:30080/clients
```

### Remover os recursos

```bash
./delete-kind.sh
```

---

## Testes de carga

Os testes utilizam [k6](https://k6.io) e são compostos por dois scripts executados em sequência pelo `run-test.sh` de cada cenário:

### Teste de carga normal (`k6-script.js`)

Simula um ramp-up progressivo de usuários virtuais (VUs):

| Fase | Duração | VUs |
|---|---|---|
| Rampa de subida | 30s | 0 → 20 |
| Carga sustentada | 60s | 20 → 50 |
| Pico | 120s | 50 → 100 |
| Rampa de descida | 30s | 100 → 0 |

**Thresholds:** P95 < 1000ms, taxa de erro < 1%.

### Teste de falha e recuperação (`fault-test.sh`)

Executa 30 VUs por 120s e, após 10s de aquecimento, simula uma falha:

- **Docker:** `docker compose down` seguido de `docker compose up -d`
- **K8s:** `kubectl delete pod -l app=tcc-app -n tcc --grace-period=0 --force`

Monitora o endpoint `/health` a cada 200ms para medir o tempo de indisponibilidade e de recuperação.

### Métricas capturadas

| Métrica | Arquivo |
|---|---|
| Tempo médio de resposta, P95, req/s, taxa de erro | `load-test-summary.json` |
| Métricas detalhadas por requisição | `load-test.json` |
| Tempo de recuperação e indisponibilidade (falha) | `fault-recovery.txt` |
| Log de status HTTP durante a falha | `health-monitor.log` |
| Resumo k6 do teste com falha | `fault-load-test-summary.json` |

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

Os resultados são gravados automaticamente em `load-test/results/docker/` e `load-test/results/k8s/`.

---

## Resultados obtidos

### Carga normal (ramp 0 → 100 VUs)

| Métrica | Docker | Kubernetes |
|---|---:|---:|
| Tempo médio de resposta | 3,14 ms | 3,66 ms |
| P95 do tempo de resposta | 5,93 ms | 5,97 ms |
| Requisições por segundo | 53,22 req/s | 53,28 req/s |
| Taxa de erro | 0% | 0% |

### Falha simulada (30 VUs constantes)

| Métrica | Docker | Kubernetes |
|---|---:|---:|
| Taxa de erro sob carga | 2,5% | 0% |
| P95 do tempo de resposta | 9,71 ms | 11,58 ms |
| Tempo de recuperação após falha | 825 ms | ~1 ms |
| Tempo de indisponibilidade | 825 ms | ~1 ms |

> Tabela completa em [`load-test/comparativo.md`](load-test/comparativo.md).

---

## Observações sobre os resultados

- **Carga normal:** os dois ambientes apresentam desempenho equivalente. O Docker tem latência média ~0,5ms menor, reflexo do menor overhead de rede em relação à camada de kube-proxy do Kubernetes.
- **Resiliência a falhas:** o Kubernetes manteve zero erros durante a deleção forçada do pod, pois redirecionou o tráfego imediatamente para as réplicas restantes. O Docker Compose registrou 2,5% de falhas e ficou indisponível por ~825ms enquanto o container reiniciava.
