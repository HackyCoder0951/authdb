#!/usr/bin/env bash

set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-authdb-prod}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-${NAMESPACE:-authdb}}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-/tmp/${CLUSTER_NAME}-kubeconfig}"

DASHBOARD_NAMESPACE="${DASHBOARD_NAMESPACE:-kubernetes-dashboard}"
DASHBOARD_SERVICE="${DASHBOARD_SERVICE:-kubernetes-dashboard-kong-proxy}"
DASHBOARD_LOCAL_PORT="${DASHBOARD_LOCAL_PORT:-8444}"
DASHBOARD_SERVICE_PORT="${DASHBOARD_SERVICE_PORT:-443}"
PRINT_DASHBOARD_TOKEN="${PRINT_DASHBOARD_TOKEN:-true}"
DASHBOARD_SERVICE_ACCOUNT="${DASHBOARD_SERVICE_ACCOUNT:-admin-user}"

RABBITMQ_SERVICE="${RABBITMQ_SERVICE:-rabbitmq}"
RABBITMQ_LOCAL_PORT="${RABBITMQ_LOCAL_PORT:-15672}"
RABBITMQ_SERVICE_PORT="${RABBITMQ_SERVICE_PORT:-15672}"

FRONTEND_SERVICE="${FRONTEND_SERVICE:-frontend}"
FRONTEND_LOCAL_PORT="${FRONTEND_LOCAL_PORT:-8081}"
FRONTEND_SERVICE_PORT="${FRONTEND_SERVICE_PORT:-80}"

BIND_ADDRESS="${BIND_ADDRESS:-127.0.0.1}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

pids=()

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

cleanup() {
  if ((${#pids[@]} > 0)); then
    log "Stopping port-forwards"
    for pid in "${pids[@]}"; do
      kill "$pid" >/dev/null 2>&1 || true
    done
    wait >/dev/null 2>&1 || true
  fi
}

port_in_use() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ltn "( sport = :$port )" | awk 'NR > 1 {found=1} END {exit !found}'
  elif command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
  else
    return 1
  fi
}

start_forward() {
  local label="$1"
  local namespace="$2"
  local service="$3"
  local local_port="$4"
  local service_port="$5"
  local log_file="/tmp/authdb-port-forward-${label}.log"

  kubectl_aws get svc "$service" -n "$namespace" >/dev/null

  if port_in_use "$local_port"; then
    fail "Local port $local_port is already in use. Change the ${label^^}_LOCAL_PORT env var."
  fi

  log "Forwarding $label: $BIND_ADDRESS:$local_port -> svc/$service:$service_port in namespace $namespace"
  kubectl_aws port-forward \
    --address "$BIND_ADDRESS" \
    -n "$namespace" \
    "svc/$service" \
    "$local_port:$service_port" >"$log_file" 2>&1 &

  pids+=("$!")
}

trap cleanup EXIT INT TERM

need_cmd aws
need_cmd kubectl

log "Connecting kubectl to AWS EKS cluster $CLUSTER_NAME in $AWS_REGION"
KUBECONFIG="$KUBECONFIG_PATH" aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null

start_forward dashboard "$DASHBOARD_NAMESPACE" "$DASHBOARD_SERVICE" "$DASHBOARD_LOCAL_PORT" "$DASHBOARD_SERVICE_PORT"
start_forward rabbitmq "$KUBE_NAMESPACE" "$RABBITMQ_SERVICE" "$RABBITMQ_LOCAL_PORT" "$RABBITMQ_SERVICE_PORT"
start_forward frontend "$KUBE_NAMESPACE" "$FRONTEND_SERVICE" "$FRONTEND_LOCAL_PORT" "$FRONTEND_SERVICE_PORT"

sleep 2

for pid in "${pids[@]}"; do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    fail "A port-forward failed to start. Check /tmp/authdb-port-forward-*.log"
  fi
done

log "Local access URLs"
printf '  Kubernetes Dashboard: https://%s:%s\n' "$BIND_ADDRESS" "$DASHBOARD_LOCAL_PORT"
printf '  RabbitMQ Management: http://%s:%s\n' "$BIND_ADDRESS" "$RABBITMQ_LOCAL_PORT"
printf '  Frontend:            http://%s:%s\n' "$BIND_ADDRESS" "$FRONTEND_LOCAL_PORT"

if [[ "$PRINT_DASHBOARD_TOKEN" == "true" ]]; then
  if kubectl_aws get serviceaccount "$DASHBOARD_SERVICE_ACCOUNT" -n "$DASHBOARD_NAMESPACE" >/dev/null 2>&1; then
    log "Kubernetes Dashboard token for service account $DASHBOARD_SERVICE_ACCOUNT"
    kubectl_aws -n "$DASHBOARD_NAMESPACE" create token "$DASHBOARD_SERVICE_ACCOUNT"
  else
    warn "Dashboard service account $DASHBOARD_SERVICE_ACCOUNT was not found in namespace $DASHBOARD_NAMESPACE"
  fi
fi

log "Port-forwards are running. Press Ctrl+C to stop."
wait
