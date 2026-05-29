#!/usr/bin/env bash

set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-authdb-prod}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-${NAMESPACE:-authdb}}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-/tmp/${CLUSTER_NAME}-kubeconfig}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-300}"
SLEEP_SECONDS="${SLEEP_SECONDS:-5}"
CHECK_FRONTEND_LB="${CHECK_FRONTEND_LB:-true}"
CHECK_GATEWAY_LB="${CHECK_GATEWAY_LB:-true}"

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

http_ok() {
  local url="$1"
  local expect_status_ok="${2:-false}"
  local body
  local status

  body="$(mktemp)"
  status="$(curl -fsS -m 10 -o "$body" -w '%{http_code}' "$url" || true)"

  if [[ "$status" != "200" ]]; then
    rm -f "$body"
    return 1
  fi

  if [[ "$expect_status_ok" == "true" ]] && ! grep -q '"status"[[:space:]]*:[[:space:]]*"ok"' "$body"; then
    rm -f "$body"
    return 1
  fi

  rm -f "$body"
  return 0
}

wait_for_http() {
  local name="$1"
  local url="$2"
  local expect_status_ok="${3:-false}"
  local deadline=$((SECONDS + TIMEOUT_SECONDS))

  log "Checking $name at $url"
  until http_ok "$url" "$expect_status_ok"; do
    if (( SECONDS >= deadline )); then
      fail "$name is not healthy after ${TIMEOUT_SECONDS}s"
    fi
    sleep "$SLEEP_SECONDS"
  done
}

need_cmd aws
need_cmd kubectl
need_cmd curl

log "Checking AWS EKS cluster $CLUSTER_NAME in $AWS_REGION"
status="$(aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" --query 'cluster.status' --output text)"
[[ "$status" == "ACTIVE" ]] || fail "EKS cluster status is $status"

KUBECONFIG="$KUBECONFIG_PATH" aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null

log "Checking EKS nodes"
kubectl_aws get nodes -o wide
not_ready="$(kubectl_aws get nodes --no-headers | awk '$2 != "Ready" {print}' || true)"
[[ -z "$not_ready" ]] || fail "Some EKS nodes are not Ready"

log "Checking EKS pods"
kubectl_aws wait --for=condition=Ready pods --all -n "$KUBE_NAMESPACE" --timeout="${TIMEOUT_SECONDS}s"
kubectl_aws get pods -n "$KUBE_NAMESPACE" -o wide

log "Checking deployments, services, PVCs, and HPAs"
kubectl_aws get deployments -n "$KUBE_NAMESPACE" -o wide
kubectl_aws get svc -n "$KUBE_NAMESPACE" -o wide
kubectl_aws get pvc -n "$KUBE_NAMESPACE"
kubectl_aws get hpa -n "$KUBE_NAMESPACE" || true

gateway_host="$(kubectl_aws get svc gateway -n "$KUBE_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
frontend_host="$(kubectl_aws get svc frontend -n "$KUBE_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"

if [[ "$CHECK_GATEWAY_LB" == "true" ]]; then
  [[ -n "$gateway_host" ]] || fail "Gateway LoadBalancer hostname is not available"
  wait_for_http "gateway" "http://$gateway_host/api/v1/health" true
  wait_for_http "auth service through gateway" "http://$gateway_host/api/v1/health/auth" true
  wait_for_http "user service through gateway" "http://$gateway_host/api/v1/health/users" true
  wait_for_http "task service through gateway" "http://$gateway_host/api/v1/health/tasks" true
fi

if [[ "$CHECK_FRONTEND_LB" == "true" ]]; then
  [[ -n "$frontend_host" ]] || fail "Frontend LoadBalancer hostname is not available"
  wait_for_http "frontend load balancer" "http://$frontend_host/" false
fi

log "AWS health checks passed"
