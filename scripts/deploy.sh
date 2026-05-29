#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-authdb-prod}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-${NAMESPACE:-authdb}}"
IMAGE_TAG="${IMAGE_TAG:-v1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
ECR_REGISTRY="${ECR_REGISTRY:-}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-/tmp/${CLUSTER_NAME}-kubeconfig}"
BUILD_AND_PUSH="${BUILD_AND_PUSH:-true}"
APPLY_MANIFESTS="${APPLY_MANIFESTS:-false}"
RUN_HEALTHCHECK="${RUN_HEALTHCHECK:-true}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-300s}"
REQUIRE_EXISTING_STACK="${REQUIRE_EXISTING_STACK:-true}"
CREATE_MISSING_ECR="${CREATE_MISSING_ECR:-false}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
  printf '%b[INFO]%b %s\n' "$GREEN" "$NC" "$1"
}

warn() {
  printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$1"
}

fail() {
  printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$1" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is not installed"
}

kubectl_aws() {
  KUBECONFIG="$KUBECONFIG_PATH" kubectl "$@"
}

ensure_ecr_repo() {
  local repo="$1"
  if ! aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null 2>&1; then
    if [[ "$CREATE_MISSING_ECR" == "true" ]]; then
      log "Creating ECR repository $repo"
      aws ecr create-repository --repository-name "$repo" --region "$AWS_REGION" >/dev/null
    else
      fail "Missing ECR repository: $repo. Create it first or set CREATE_MISSING_ECR=true."
    fi
  fi
}

check_ecr_repo() {
  local repo="$1"
  aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null 2>&1
}

check_k8s_resource() {
  local kind="$1"
  local name="$2"
  kubectl_aws get "$kind" "$name" -n "$KUBE_NAMESPACE" >/dev/null 2>&1
}

verify_existing_stack() {
  log "Verifying existing AWS/EKS stack before deployment"

  local cluster_status
  cluster_status="$(aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" --query 'cluster.status' --output text)"
  [[ "$cluster_status" == "ACTIVE" ]] || fail "EKS cluster $CLUSTER_NAME is not ACTIVE. Current status: $cluster_status"

  kubectl_aws get namespace "$KUBE_NAMESPACE" >/dev/null || fail "Namespace $KUBE_NAMESPACE does not exist"

  for repo in authdb/auth-service authdb/user-service authdb/task-service authdb/frontend; do
    check_ecr_repo "$repo" || fail "Missing ECR repository: $repo"
  done

  for deployment in auth-service user-service task-service frontend gateway mongodb rabbitmq; do
    check_k8s_resource deployment "$deployment" || fail "Missing deployment/$deployment in namespace $KUBE_NAMESPACE"
  done

  for service in auth-service user-service task-service frontend gateway mongodb rabbitmq; do
    check_k8s_resource service "$service" || fail "Missing service/$service in namespace $KUBE_NAMESPACE"
  done

  check_k8s_resource pvc mongodb-data || fail "Missing pvc/mongodb-data in namespace $KUBE_NAMESPACE"
  log "Existing stack verification passed"
}

build_and_push_image() {
  local dockerfile="$1"
  local image="$2"

  log "Building $image"
  docker build -f "$dockerfile" -t "$image" "$PROJECT_ROOT"
  log "Pushing $image"
  docker push "$image"
}

apply_manifest() {
  local manifest="$1"
  [[ -f "$manifest" ]] || fail "Missing manifest: $manifest"
  log "Applying ${manifest#$PROJECT_ROOT/}"
  kubectl_aws apply -f "$manifest"
}

need_cmd aws
need_cmd kubectl
need_cmd docker

log "Checking AWS identity"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
ECR_REGISTRY="${ECR_REGISTRY:-${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com}"

log "Updating kubeconfig for EKS cluster $CLUSTER_NAME in $AWS_REGION"
KUBECONFIG="$KUBECONFIG_PATH" aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null

if [[ "$REQUIRE_EXISTING_STACK" == "true" ]]; then
  verify_existing_stack
fi

if [[ "$BUILD_AND_PUSH" == "true" ]]; then
  ensure_ecr_repo authdb/auth-service
  ensure_ecr_repo authdb/user-service
  ensure_ecr_repo authdb/task-service
  ensure_ecr_repo authdb/frontend

  log "Logging Docker in to Amazon ECR"
  aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

  build_and_push_image "$PROJECT_ROOT/services/auth-services/Dockerfile" "$ECR_REGISTRY/authdb/auth-service:$IMAGE_TAG"
  build_and_push_image "$PROJECT_ROOT/services/user-services/Dockerfile" "$ECR_REGISTRY/authdb/user-service:$IMAGE_TAG"
  build_and_push_image "$PROJECT_ROOT/services/tasks-services/Dockerfile" "$ECR_REGISTRY/authdb/task-service:$IMAGE_TAG"
  build_and_push_image "$PROJECT_ROOT/frontend/Dockerfile" "$ECR_REGISTRY/authdb/frontend:$IMAGE_TAG"
fi

if [[ "$APPLY_MANIFESTS" == "true" ]]; then
  warn "APPLY_MANIFESTS=true will reconcile YAML from k8s/. Existing AWS LoadBalancer service choices may change."
  for manifest in \
    "$PROJECT_ROOT/k8s/namespace.yml" \
    "$PROJECT_ROOT/k8s/secret.yml" \
    "$PROJECT_ROOT/k8s/configmap.yml" \
    "$PROJECT_ROOT/k8s/mongodb-persistent-volume.yml" \
    "$PROJECT_ROOT/k8s/rabbitmq-deployment.yml" \
    "$PROJECT_ROOT/k8s/auth-service-deployment.yml" \
    "$PROJECT_ROOT/k8s/user-service-deployment.yml" \
    "$PROJECT_ROOT/k8s/task-service-deployment.yml" \
    "$PROJECT_ROOT/k8s/gateway-deployment.yml" \
    "$PROJECT_ROOT/k8s/frontend-deployment.yml" \
    "$PROJECT_ROOT/k8s/service.yml" \
    "$PROJECT_ROOT/k8s/ingress.yml" \
    "$PROJECT_ROOT/k8s/hpa.yml"; do
    apply_manifest "$manifest"
  done
fi

log "Updating EKS deployments to image tag $IMAGE_TAG"
kubectl_aws set image deployment/auth-service "auth-service=$ECR_REGISTRY/authdb/auth-service:$IMAGE_TAG" -n "$KUBE_NAMESPACE"
kubectl_aws set image deployment/user-service "user-service=$ECR_REGISTRY/authdb/user-service:$IMAGE_TAG" -n "$KUBE_NAMESPACE"
kubectl_aws set image deployment/task-service "task-service=$ECR_REGISTRY/authdb/task-service:$IMAGE_TAG" -n "$KUBE_NAMESPACE"
kubectl_aws set image deployment/frontend "frontend=$ECR_REGISTRY/authdb/frontend:$IMAGE_TAG" -n "$KUBE_NAMESPACE"

for deployment in auth-service user-service task-service frontend gateway mongodb rabbitmq; do
  kubectl_aws rollout status "deployment/$deployment" -n "$KUBE_NAMESPACE" --timeout="$ROLLOUT_TIMEOUT"
done

if [[ "$RUN_HEALTHCHECK" == "true" ]]; then
  AWS_REGION="$AWS_REGION" CLUSTER_NAME="$CLUSTER_NAME" NAMESPACE="$KUBE_NAMESPACE" KUBECONFIG_PATH="$KUBECONFIG_PATH" "$SCRIPT_DIR/healthcheck.sh"
fi

log "AWS EKS deployment finished"
