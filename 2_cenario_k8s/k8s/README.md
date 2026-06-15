This folder contains Kubernetes manifests and helper scripts to run the same application as in the Docker Compose scenario, but on a local Kind cluster.

Files:

- `namespace.yaml` - creates namespace `tcc`.
- `mysql-configmap.yaml` - ConfigMap containing `init.sql` used to initialize MySQL.
- `mysql-deployment.yaml` - MySQL Service + Deployment (uses `emptyDir` for storage for local testing).
- `app-deployment.yaml` - Application Service (NodePort) + Deployment. Image name expected: `1_cenario_docker-app:latest` with `imagePullPolicy: Never`.
- `build-and-load-kind.sh` - Builds the app image from `../app` and loads it into Kind.
- `apply-kind.sh` - Applies the manifests to the Kind cluster and waits for rollouts.
- `delete-kind.sh` - Deletes the resources.

Quick start:

1. Create a kind cluster (if you don't have one):

```bash
kind create cluster --name kind
```

2. Build app image and load into kind:

```bash
cd 2_cenario_k8s/k8s
./build-and-load-kind.sh kind 1_cenario_docker-app:latest
```

3. Apply manifests:

```bash
./apply-kind.sh
```

4. Get the NodePort and curl the app (on the host where kind runs):

```bash
kubectl get nodes -o wide
# NodePort is 30080
curl http://localhost:30080/health
```

Cleanup:

```bash
./delete-kind.sh
```

Ambiente — Cenário 2 — Kubernetes com kind:

- vCPUs: 2
- Memória RAM: 4 GB
