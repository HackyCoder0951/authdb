#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
IMAGE_TAG="${IMAGE_TAG:-v1}"

AUTH_REPO="$(terraform -chdir="${SCRIPT_DIR}" output -raw auth_service_ecr_repository_url)"
USER_REPO="$(terraform -chdir="${SCRIPT_DIR}" output -raw user_service_ecr_repository_url)"
TASK_REPO="$(terraform -chdir="${SCRIPT_DIR}" output -raw task_service_ecr_repository_url)"
FRONTEND_REPO="$(terraform -chdir="${SCRIPT_DIR}" output -raw frontend_ecr_repository_url)"
DOCKER_LOGIN_COMMAND="$(terraform -chdir="${SCRIPT_DIR}" output -raw docker_login_command)"

cd "${REPO_ROOT}"

echo "Logging in to ECR"
eval "${DOCKER_LOGIN_COMMAND}"

echo "Building images with tag ${IMAGE_TAG}"
docker build -f services/auth-services/Dockerfile -t "${AUTH_REPO}:${IMAGE_TAG}" .
docker build -f services/user-services/Dockerfile -t "${USER_REPO}:${IMAGE_TAG}" .
docker build -f services/tasks-services/Dockerfile -t "${TASK_REPO}:${IMAGE_TAG}" .
docker build -f frontend/Dockerfile -t "${FRONTEND_REPO}:${IMAGE_TAG}" .

echo "Pushing images"
docker push "${AUTH_REPO}:${IMAGE_TAG}"
docker push "${USER_REPO}:${IMAGE_TAG}"
docker push "${TASK_REPO}:${IMAGE_TAG}"
docker push "${FRONTEND_REPO}:${IMAGE_TAG}"

echo "Done"
