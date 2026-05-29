#!/usr/bin/env bash

set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-authdb-prod}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-${NAMESPACE:-authdb}}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-/tmp/${CLUSTER_NAME}-kubeconfig}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-300s}"
ROLLBACK_DEPLOYMENTS="${ROLLBACK_DEPLOYMENTS:-frontend gateway task-service user-service auth-service}"
REVISION="${REVISION:-}"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
  printf '%b[INFO]%b %s\n' "$GREEN" "$NC" "$1"
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

log "Updating kubeconfig for AWS EKS cluster $CLUSTER_NAME in $AWS_REGION"
KUBECONFIG="$KUBECONFIG_PATH" aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null
kubectl_aws get namespace "$KUBE_NAMESPACE" >/dev/null

for deployment in $ROLLBACK_DEPLOYMENTS; do
  log "Rolling back deployment/$deployment on EKS"
  if [[ -n "$REVISION" ]]; then
    kubectl_aws rollout undo "deployment/$deployment" -n "$KUBE_NAMESPACE" --to-revision="$REVISION"
  else
    kubectl_aws rollout undo "deployment/$deployment" -n "$KUBE_NAMESPACE"
  fi

  kubectl_aws rollout status "deployment/$deployment" -n "$KUBE_NAMESPACE" --timeout="$ROLLOUT_TIMEOUT"
done

log "AWS rollback complete"
