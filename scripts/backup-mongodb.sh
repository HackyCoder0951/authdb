#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-authdb-prod}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-${NAMESPACE:-authdb}}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-/tmp/${CLUSTER_NAME}-kubeconfig}"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backups/mongodb}"
BACKUP_S3_URI="${BACKUP_S3_URI:-}"

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

log "Updating kubeconfig for AWS EKS cluster $CLUSTER_NAME in $AWS_REGION"
KUBECONFIG="$KUBECONFIG_PATH" aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null

mkdir -p "$BACKUP_DIR"
archive="$BACKUP_DIR/authdb-mongodb-$(date +%Y%m%d-%H%M%S).archive.gz"

log "Reading MongoDB credentials from EKS secret"
user="$(kubectl_aws get secret authdb-secret -n "$KUBE_NAMESPACE" -o jsonpath='{.data.MONGODB_ROOT_USER}' | base64 --decode)"
password="$(kubectl_aws get secret authdb-secret -n "$KUBE_NAMESPACE" -o jsonpath='{.data.MONGODB_ROOT_PASSWORD}' | base64 --decode)"

log "Backing up MongoDB from EKS deployment/mongodb"
kubectl_aws exec -n "$KUBE_NAMESPACE" deployment/mongodb -- \
  mongodump --archive --gzip --username "$user" --password "$password" --authenticationDatabase admin > "$archive"

log "Backup complete: $archive"

if [[ -n "$BACKUP_S3_URI" ]]; then
  log "Uploading backup to $BACKUP_S3_URI"
  aws s3 cp "$archive" "$BACKUP_S3_URI/"
else
  warn "BACKUP_S3_URI is not set; backup was kept on this machine only"
fi
