#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${1:-tcc}

kubectl apply -f namespace.yaml
kubectl apply -n "$NAMESPACE" -f mysql-configmap.yaml
kubectl apply -n "$NAMESPACE" -f mysql-deployment.yaml
kubectl apply -n "$NAMESPACE" -f app-deployment.yaml

kubectl -n "$NAMESPACE" rollout status deployment/mysql --timeout=120s
kubectl -n "$NAMESPACE" rollout status deployment/tcc-app --timeout=120s

echo "All resources applied in namespace $NAMESPACE. Access app via NodePort (port 30080) on the Kind node host." 
