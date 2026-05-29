#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="${TF_DIR:-$PROJECT_ROOT/terraform/aws-eks}"

AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-authdb-prod}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-${NAMESPACE:-authdb}}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-/tmp/${CLUSTER_NAME}-kubeconfig}"
CLEANUP_MODE="${CLEANUP_MODE:-workloads}"
CONFIRM_CLEANUP="${CONFIRM_CLEANUP:-}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"

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

terraform_destroy() {
  [[ -d "$TF_DIR" ]] || fail "Terraform directory not found: $TF_DIR"
  need_cmd terraform

  if [[ "$AUTO_APPROVE" == "true" ]]; then
    terraform -chdir="$TF_DIR" destroy -auto-approve
  else
    terraform -chdir="$TF_DIR" destroy
  fi
}

need_cmd aws

case "$CLEANUP_MODE" in
  workloads)
    need_cmd kubectl
    [[ "$CONFIRM_CLEANUP" == "$KUBE_NAMESPACE" ]] || fail "Set CONFIRM_CLEANUP=$KUBE_NAMESPACE to delete AWS EKS workloads"

    log "Updating kubeconfig for AWS EKS cluster $CLUSTER_NAME in $AWS_REGION"
    KUBECONFIG="$KUBECONFIG_PATH" aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null

    warn "Deleting AuthDB workloads from namespace $KUBE_NAMESPACE"
    for resource in hpa ingress service deployment pvc configmap secret; do
      kubectl_aws delete "$resource" -l app.kubernetes.io/name -n "$KUBE_NAMESPACE" --ignore-not-found=true
    done
    ;;
  namespace)
    need_cmd kubectl
    [[ "$CONFIRM_CLEANUP" == "$KUBE_NAMESPACE" ]] || fail "Set CONFIRM_CLEANUP=$KUBE_NAMESPACE to delete the AWS EKS namespace"

    log "Updating kubeconfig for AWS EKS cluster $CLUSTER_NAME in $AWS_REGION"
    KUBECONFIG="$KUBECONFIG_PATH" aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null
    warn "Deleting namespace $KUBE_NAMESPACE"
    kubectl_aws delete namespace "$KUBE_NAMESPACE" --ignore-not-found=true
    ;;
  terraform-destroy)
    [[ "$CONFIRM_CLEANUP" == "destroy-aws" ]] || fail "Set CONFIRM_CLEANUP=destroy-aws to destroy Terraform-managed AWS infrastructure"
    warn "Destroying Terraform-managed AWS infrastructure"
    terraform_destroy
    ;;
  *)
    fail "Unsupported CLEANUP_MODE '$CLEANUP_MODE'. Use 'workloads', 'namespace', or 'terraform-destroy'."
    ;;
esac

log "AWS cleanup complete"
