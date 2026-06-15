Cenário 1 — Docker sem orquestração

Ambiente:

- vCPUs: 2
- Memória RAM: 4 GB
- Armazenamento: 20 GB
- Sistema operacional base: Ubuntu 26.04 LTS
- Docker: v29.5.3
- Kubernetes: não utilizado
- kind: não utilizado
- Estrutura: 2 containers, sendo 1 para aplicação PHP/Nginx e 1 para MySQL.

Uso rápido:

```bash
docker compose up --build
```
