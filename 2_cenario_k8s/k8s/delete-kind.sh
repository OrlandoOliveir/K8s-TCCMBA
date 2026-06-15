#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${1:-tcc}

kubectl delete -n "$NAMESPACE" -f app-deployment.yaml || true
kubectl delete -n "$NAMESPACE" -f mysql-deployment.yaml || true
kubectl delete -n "$NAMESPACE" -f mysql-configmap.yaml || true
kubectl delete -f namespace.yaml || true

echo "Resources deleted (namespace: $NAMESPACE)."
