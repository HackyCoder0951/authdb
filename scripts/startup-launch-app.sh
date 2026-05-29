#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-authdb-prod}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-${NAMESPACE:-authdb}}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-/tmp/${CLUSTER_NAME}-kubeconfig}"
RUN_HEALTHCHECK="${RUN_HEALTHCHECK:-true}"

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

log "Connecting kubectl to AWS EKS cluster $CLUSTER_NAME in $AWS_REGION"
KUBECONFIG="$KUBECONFIG_PATH" aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null

log "Current EKS workloads"
kubectl_aws get nodes -o wide
kubectl_aws get pods -n "$KUBE_NAMESPACE" -o wide
kubectl_aws get svc -n "$KUBE_NAMESPACE" -o wide
kubectl_aws get pvc -n "$KUBE_NAMESPACE"

if [[ "$RUN_HEALTHCHECK" == "true" ]]; then
  AWS_REGION="$AWS_REGION" CLUSTER_NAME="$CLUSTER_NAME" NAMESPACE="$KUBE_NAMESPACE" KUBECONFIG_PATH="$KUBECONFIG_PATH" "$SCRIPT_DIR/healthcheck.sh"
fi

frontend_url="$(kubectl_aws get svc frontend -n "$KUBE_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
gateway_url="$(kubectl_aws get svc gateway -n "$KUBE_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
[[ -n "$frontend_url" ]] && log "Frontend URL: http://$frontend_url" || warn "Frontend LoadBalancer hostname is not ready"
[[ -n "$gateway_url" ]] && log "Gateway URL:  http://$gateway_url" || warn "Gateway LoadBalancer hostname is not ready"
