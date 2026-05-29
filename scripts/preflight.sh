#!/usr/bin/env bash

set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-authdb-prod}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-${NAMESPACE:-authdb}}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
ECR_REGISTRY="${ECR_REGISTRY:-}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-/tmp/${CLUSTER_NAME}-kubeconfig}"
CHECK_DOCKER="${CHECK_DOCKER:-true}"
CHECK_EBS_ADDON="${CHECK_EBS_ADDON:-true}"

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

need_cmd aws
need_cmd kubectl
[[ "$CHECK_DOCKER" == "true" ]] && need_cmd docker

log "Checking AWS identity"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
ECR_REGISTRY="${ECR_REGISTRY:-${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com}"
log "Using ECR registry $ECR_REGISTRY"

log "Checking EKS cluster $CLUSTER_NAME in $AWS_REGION"
status="$(aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" --query 'cluster.status' --output text)"
[[ "$status" == "ACTIVE" ]] || fail "EKS cluster status is $status"

if [[ "$CHECK_EBS_ADDON" == "true" ]]; then
  if ! aws eks describe-addon --region "$AWS_REGION" --cluster-name "$CLUSTER_NAME" --addon-name aws-ebs-csi-driver >/dev/null 2>&1; then
    warn "AWS EBS CSI driver add-on is not installed. Existing PVCs may still work, but new EBS PVCs can fail."
  fi
fi

log "Checking ECR repositories"
for repo in authdb/auth-service authdb/user-service authdb/task-service authdb/frontend; do
  aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null || warn "Missing ECR repository: $repo"
done

log "Updating kubeconfig"
KUBECONFIG="$KUBECONFIG_PATH" aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null

log "Checking EKS nodes and namespace"
kubectl_aws get nodes -o wide
kubectl_aws get namespace "$KUBE_NAMESPACE" >/dev/null

not_ready="$(kubectl_aws get nodes --no-headers | awk '$2 != "Ready" {print}' || true)"
[[ -z "$not_ready" ]] || fail "Some EKS nodes are not Ready"

if [[ "$CHECK_DOCKER" == "true" ]]; then
  log "Checking Docker daemon"
  docker info >/dev/null
fi

log "AWS preflight checks passed"
