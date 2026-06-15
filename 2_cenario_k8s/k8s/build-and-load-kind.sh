#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME=${1:-kind}
IMAGE_NAME=${2:-1_cenario_docker-app:latest}
APP_DIR="../app"

echo "Building Docker image ${IMAGE_NAME} from ${APP_DIR}..."
docker build -t "${IMAGE_NAME}" "${APP_DIR}"

echo "Loading image into kind cluster '${CLUSTER_NAME}'..."
kind load docker-image "${IMAGE_NAME}" --name "${CLUSTER_NAME}"

echo "Done. Image ${IMAGE_NAME} is available in kind cluster ${CLUSTER_NAME}."
