#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="${TF_DIR:-$PROJECT_ROOT/terraform/aws-eks}"

AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-authdb-prod}"
PROJECT_NAME="${PROJECT_NAME:-authdb}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-${NAMESPACE:-authdb}}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-/tmp/${CLUSTER_NAME}-kubeconfig}"

CLEANUP_MODE="${CLEANUP_MODE:-full-stack}"
CONFIRM_CLEANUP="${CONFIRM_CLEANUP:-}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"
EMPTY_ECR_REPOS="${EMPTY_ECR_REPOS:-true}"
DISABLE_K8S_FIRST="${DISABLE_K8S_FIRST:-true}"
WAIT_TIMEOUT_SECONDS="${WAIT_TIMEOUT_SECONDS:-900}"
CLEANUP_BACKEND="${CLEANUP_BACKEND:-auto}"
DELETE_VPC="${DELETE_VPC:-true}"
VPC_ID="${VPC_ID:-}"
DELETE_IAM_ROLES="${DELETE_IAM_ROLES:-true}"
DELETE_EXTRA_NAMESPACES="${DELETE_EXTRA_NAMESPACES:-true}"
EXTRA_NAMESPACES="${EXTRA_NAMESPACES:-kubernetes-dashboard}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

started_at="$(date +%s)"

log() {
  printf '%b[%s] [INFO]%b %s\n' "$GREEN" "$(date '+%Y-%m-%d %H:%M:%S')" "$NC" "$1"
}

warn() {
  printf '%b[%s] [WARN]%b %s\n' "$YELLOW" "$(date '+%Y-%m-%d %H:%M:%S')" "$NC" "$1"
}

fail() {
  printf '%b[%s] [ERROR]%b %s\n' "$RED" "$(date '+%Y-%m-%d %H:%M:%S')" "$NC" "$1" >&2
  exit 1
}

step() {
  printf '\n%b========== %s ==========%b\n' "$BLUE" "$1" "$NC"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is not installed"
}

kubectl_aws() {
  KUBECONFIG="$KUBECONFIG_PATH" kubectl "$@"
}

tf() {
  terraform -chdir="$TF_DIR" "$@"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

tf_apply() {
  local args=("$@")
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    tf apply -auto-approve "${args[@]}"
  else
    tf apply "${args[@]}"
  fi
}

tf_destroy() {
  local args=("$@")
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    tf destroy -auto-approve "${args[@]}"
  else
    tf destroy "${args[@]}"
  fi
}

confirm_destructive_action() {
  local required="destroy-${CLUSTER_NAME}"
  [[ "$CONFIRM_CLEANUP" == "$required" ]] || fail "This deletes the AWS EKS stack. Set CONFIRM_CLEANUP=$required to continue."
}

tf_var_args() {
  printf '%s\n' \
    "-var=aws_region=$AWS_REGION" \
    "-var=cluster_name=$CLUSTER_NAME" \
    "-var=project_name=$PROJECT_NAME"
}

cluster_exists() {
  aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null 2>&1
}

print_aws_status() {
  step "AWS Status"
  log "AWS identity"
  aws sts get-caller-identity

  if cluster_exists; then
    log "EKS cluster status"
    aws eks describe-cluster \
      --region "$AWS_REGION" \
      --name "$CLUSTER_NAME" \
      --query 'cluster.{name:name,status:status,version:version,endpoint:endpoint}' \
      --output table
    log "EKS node groups"
    aws eks list-nodegroups --region "$AWS_REGION" --cluster-name "$CLUSTER_NAME" --output table || true
    log "EKS add-ons"
    aws eks list-addons --region "$AWS_REGION" --cluster-name "$CLUSTER_NAME" --output table || true
  else
    warn "EKS cluster $CLUSTER_NAME is not present in $AWS_REGION"
  fi

  discover_vpc_id >/dev/null || true
  if [[ -n "$VPC_ID" ]]; then
    log "Relevant VPC status"
    aws ec2 describe-vpcs --region "$AWS_REGION" --vpc-ids "$VPC_ID" --query 'Vpcs[].{VpcId:VpcId,State:State,Cidr:CidrBlock}' --output table || true
  fi
}

print_k8s_status() {
  step "Kubernetes Status"
  if ! cluster_exists; then
    warn "Skipping Kubernetes status because the EKS cluster does not exist"
    return 0
  fi

  KUBECONFIG="$KUBECONFIG_PATH" aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null
  kubectl_aws get nodes -o wide || true
  kubectl_aws get pods -n "$KUBE_NAMESPACE" -o wide || true
  kubectl_aws get svc -n "$KUBE_NAMESPACE" -o wide || true
  kubectl_aws get pvc -n "$KUBE_NAMESPACE" || true
  kubectl_aws get hpa -n "$KUBE_NAMESPACE" || true
}

print_terraform_status() {
  step "Terraform Status"
  if ! has_cmd terraform; then
    warn "Terraform is not installed; skipping Terraform status"
    return 0
  fi

  [[ -d "$TF_DIR" ]] || fail "Terraform directory not found: $TF_DIR"
  tf init
  log "Terraform workspace: $(tf workspace show)"
  log "Terraform-managed resources"
  tf state list || warn "Terraform state is empty or unavailable"
}

empty_ecr_repo() {
  local repo="$1"
  local image_ids

  if ! aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null 2>&1; then
    warn "ECR repository not found: $repo"
    return 0
  fi

  image_ids="$(aws ecr list-images --repository-name "$repo" --region "$AWS_REGION" --query 'imageIds' --output json)"
  if [[ "$image_ids" == "[]" ]]; then
    log "ECR repository is already empty: $repo"
    return 0
  fi

  warn "Deleting images from ECR repository: $repo"
  aws ecr batch-delete-image --repository-name "$repo" --region "$AWS_REGION" --image-ids "$image_ids" >/dev/null
}

empty_ecr_repos() {
  step "ECR Cleanup"
  if [[ "$EMPTY_ECR_REPOS" != "true" ]]; then
    warn "Skipping ECR image deletion because EMPTY_ECR_REPOS=$EMPTY_ECR_REPOS"
    return 0
  fi

  empty_ecr_repo "$PROJECT_NAME/auth-service"
  empty_ecr_repo "$PROJECT_NAME/user-service"
  empty_ecr_repo "$PROJECT_NAME/task-service"
  empty_ecr_repo "$PROJECT_NAME/frontend"
}

disable_kubernetes_workloads() {
  step "Disable Kubernetes Workloads"
  if [[ "$DISABLE_K8S_FIRST" != "true" ]]; then
    warn "Skipping Terraform deploy_kubernetes=false because DISABLE_K8S_FIRST=$DISABLE_K8S_FIRST"
    return 0
  fi

  mapfile -t vars < <(tf_var_args)
  log "Destroying Kubernetes workloads managed by Terraform before infrastructure teardown"
  tf_apply "${vars[@]}" -var=deploy_kubernetes=false
}

destroy_terraform_stack() {
  step "Terraform Destroy"
  mapfile -t vars < <(tf_var_args)
  warn "Destroying Terraform-managed AWS stack for cluster $CLUSTER_NAME in $AWS_REGION"
  tf_destroy "${vars[@]}"
}

delete_namespace_wait() {
  local namespace="$1"
  if ! kubectl_aws get namespace "$namespace" >/dev/null 2>&1; then
    warn "Namespace $namespace does not exist"
    return 0
  fi

  warn "Deleting namespace $namespace"
  kubectl_aws delete namespace "$namespace" --ignore-not-found=true

  local deadline=$((SECONDS + WAIT_TIMEOUT_SECONDS))
  until ! kubectl_aws get namespace "$namespace" >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
      fail "Timed out waiting for namespace $namespace deletion"
    fi
    log "Waiting for namespace $namespace to finish terminating"
    sleep 15
  done

  log "Namespace $namespace deleted"
}

delete_kubernetes_namespace_cli() {
  step "Kubernetes Cleanup via AWS CLI"
  if ! cluster_exists; then
    warn "Skipping Kubernetes cleanup because EKS cluster $CLUSTER_NAME does not exist"
    return 0
  fi

  KUBECONFIG="$KUBECONFIG_PATH" aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null

  warn "Deleting application namespace. This also removes LoadBalancer services so AWS ELBs can be cleaned up."
  delete_namespace_wait "$KUBE_NAMESPACE"

  if [[ "$DELETE_EXTRA_NAMESPACES" == "true" ]]; then
    local namespace
    for namespace in $EXTRA_NAMESPACES; do
      [[ -z "$namespace" ]] && continue
      delete_namespace_wait "$namespace"
    done
  fi
}

discover_vpc_id() {
  if [[ -n "$VPC_ID" ]]; then
    printf '%s\n' "$VPC_ID"
    return 0
  fi

  if cluster_exists; then
    VPC_ID="$(aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null || true)"
    [[ "$VPC_ID" == "None" ]] && VPC_ID=""
  fi

  if [[ -z "$VPC_ID" ]]; then
    VPC_ID="$(aws ec2 describe-vpcs \
      --region "$AWS_REGION" \
      --filters "Name=tag:Project,Values=$PROJECT_NAME" \
      --query 'Vpcs[0].VpcId' \
      --output text 2>/dev/null || true)"
    [[ "$VPC_ID" == "None" ]] && VPC_ID=""
  fi

  [[ -n "$VPC_ID" ]]
}

wait_for_load_balancers_deleted() {
  [[ -n "$VPC_ID" ]] || return 0
  local deadline=$((SECONDS + WAIT_TIMEOUT_SECONDS))

  while true; do
    local clb_count
    local v2_count
    clb_count="$(aws elb describe-load-balancers --region "$AWS_REGION" --query "length(LoadBalancerDescriptions[?VPCId=='$VPC_ID'])" --output text 2>/dev/null || printf '0')"
    v2_count="$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query "length(LoadBalancers[?VpcId=='$VPC_ID'])" --output text 2>/dev/null || printf '0')"

    if [[ "$clb_count" == "0" && "$v2_count" == "0" ]]; then
      log "All load balancers for $VPC_ID are deleted"
      return 0
    fi

    if (( SECONDS >= deadline )); then
      fail "Timed out waiting for load balancers to delete. Remaining classic=$clb_count v2=$v2_count"
    fi

    log "Waiting for load balancers to delete. Remaining classic=$clb_count v2=$v2_count"
    sleep 20
  done
}

delete_nat_gateways_cli() {
  [[ -n "$VPC_ID" ]] || return 0

  local nat_gateway_ids
  mapfile -t nat_gateway_ids < <(aws ec2 describe-nat-gateways \
    --region "$AWS_REGION" \
    --filter "Name=vpc-id,Values=$VPC_ID" \
    --query "NatGateways[?State!='deleted'].NatGatewayId" \
    --output text | tr '\t' '\n')

  if ((${#nat_gateway_ids[@]} == 0)) || [[ -z "${nat_gateway_ids[*]}" ]]; then
    log "No active NAT gateways found in $VPC_ID"
    return 0
  fi

  local nat_gateway_id
  for nat_gateway_id in "${nat_gateway_ids[@]}"; do
    [[ -z "$nat_gateway_id" ]] && continue
    warn "Deleting NAT gateway: $nat_gateway_id"
    aws ec2 delete-nat-gateway --region "$AWS_REGION" --nat-gateway-id "$nat_gateway_id" >/dev/null || true
  done

  local deadline=$((SECONDS + WAIT_TIMEOUT_SECONDS))
  while true; do
    local active_count
    active_count="$(aws ec2 describe-nat-gateways \
      --region "$AWS_REGION" \
      --filter "Name=vpc-id,Values=$VPC_ID" \
      --query "length(NatGateways[?State!='deleted'])" \
      --output text 2>/dev/null || printf '0')"

    if [[ "$active_count" == "0" ]]; then
      log "All NAT gateways in $VPC_ID are deleted"
      return 0
    fi

    if (( SECONDS >= deadline )); then
      fail "Timed out waiting for NAT gateways to reach deleted state. Remaining active count=$active_count"
    fi

    log "Waiting for NAT gateways to delete. Remaining active count=$active_count"
    sleep 20
  done
}

release_nat_gateway_eips_cli() {
  [[ -n "$VPC_ID" ]] || return 0

  local allocation_ids
  mapfile -t allocation_ids < <(aws ec2 describe-nat-gateways \
    --region "$AWS_REGION" \
    --filter "Name=vpc-id,Values=$VPC_ID" \
    --query 'NatGateways[].NatGatewayAddresses[].AllocationId' \
    --output text | tr '\t' '\n')

  if ((${#allocation_ids[@]} == 0)) || [[ -z "${allocation_ids[*]}" ]]; then
    log "No NAT gateway Elastic IP allocations found in $VPC_ID"
    return 0
  fi

  local allocation_id
  for allocation_id in "${allocation_ids[@]}"; do
    [[ -z "$allocation_id" || "$allocation_id" == "None" ]] && continue
    warn "Releasing NAT gateway Elastic IP allocation: $allocation_id"
    aws ec2 release-address --region "$AWS_REGION" --allocation-id "$allocation_id" || true
  done
}

delete_ecr_repo_cli() {
  local repo="$1"
  if ! aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null 2>&1; then
    warn "ECR repository not found: $repo"
    return 0
  fi

  warn "Deleting ECR repository with images: $repo"
  aws ecr delete-repository --repository-name "$repo" --region "$AWS_REGION" --force >/dev/null
}

delete_ecr_repos_cli() {
  step "ECR Repository Cleanup via AWS CLI"
  delete_ecr_repo_cli "$PROJECT_NAME/auth-service"
  delete_ecr_repo_cli "$PROJECT_NAME/user-service"
  delete_ecr_repo_cli "$PROJECT_NAME/task-service"
  delete_ecr_repo_cli "$PROJECT_NAME/frontend"
}

delete_eks_addons_cli() {
  step "EKS Add-on Cleanup via AWS CLI"
  if ! cluster_exists; then
    warn "Skipping add-on cleanup because EKS cluster $CLUSTER_NAME does not exist"
    return 0
  fi

  mapfile -t addons < <(aws eks list-addons --region "$AWS_REGION" --cluster-name "$CLUSTER_NAME" --query 'addons[]' --output text | tr '\t' '\n')
  if ((${#addons[@]} == 0)); then
    log "No EKS add-ons found"
    return 0
  fi

  local addon
  for addon in "${addons[@]}"; do
    [[ -z "$addon" ]] && continue
    warn "Deleting EKS add-on: $addon"
    aws eks delete-addon --region "$AWS_REGION" --cluster-name "$CLUSTER_NAME" --addon-name "$addon" >/dev/null || true
  done

  local deadline=$((SECONDS + WAIT_TIMEOUT_SECONDS))
  while true; do
    mapfile -t addons < <(aws eks list-addons --region "$AWS_REGION" --cluster-name "$CLUSTER_NAME" --query 'addons[]' --output text | tr '\t' '\n')
    if ((${#addons[@]} == 0)) || [[ -z "${addons[*]}" ]]; then
      log "All EKS add-ons deleted"
      return 0
    fi
    if (( SECONDS >= deadline )); then
      fail "Timed out waiting for EKS add-ons to delete: ${addons[*]}"
    fi
    log "Waiting for EKS add-ons to delete: ${addons[*]}"
    sleep 20
  done
}

delete_eks_nodegroups_cli() {
  step "EKS Node Group Cleanup via AWS CLI"
  if ! cluster_exists; then
    warn "Skipping node group cleanup because EKS cluster $CLUSTER_NAME does not exist"
    return 0
  fi

  mapfile -t nodegroups < <(aws eks list-nodegroups --region "$AWS_REGION" --cluster-name "$CLUSTER_NAME" --query 'nodegroups[]' --output text | tr '\t' '\n')
  if ((${#nodegroups[@]} == 0)) || [[ -z "${nodegroups[*]}" ]]; then
    log "No EKS node groups found"
    return 0
  fi

  local nodegroup
  for nodegroup in "${nodegroups[@]}"; do
    [[ -z "$nodegroup" ]] && continue
    warn "Deleting EKS node group: $nodegroup"
    aws eks delete-nodegroup --region "$AWS_REGION" --cluster-name "$CLUSTER_NAME" --nodegroup-name "$nodegroup" >/dev/null || true
  done

  local deadline=$((SECONDS + WAIT_TIMEOUT_SECONDS))
  for nodegroup in "${nodegroups[@]}"; do
    [[ -z "$nodegroup" ]] && continue
    until ! aws eks describe-nodegroup --region "$AWS_REGION" --cluster-name "$CLUSTER_NAME" --nodegroup-name "$nodegroup" >/dev/null 2>&1; do
      if (( SECONDS >= deadline )); then
        fail "Timed out waiting for node group $nodegroup deletion"
      fi
      local status
      status="$(aws eks describe-nodegroup --region "$AWS_REGION" --cluster-name "$CLUSTER_NAME" --nodegroup-name "$nodegroup" --query 'nodegroup.status' --output text 2>/dev/null || true)"
      log "Node group $nodegroup status: ${status:-not-found}"
      sleep 20
    done
    log "Node group $nodegroup deleted"
  done
}

delete_eks_cluster_cli() {
  step "EKS Cluster Cleanup via AWS CLI"
  if ! cluster_exists; then
    warn "EKS cluster $CLUSTER_NAME already deleted"
    return 0
  fi

  warn "Deleting EKS cluster: $CLUSTER_NAME"
  aws eks delete-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null
  wait_for_cluster_deleted
}

delete_vpc_cli() {
  step "VPC Cleanup via AWS CLI"
  if [[ "$DELETE_VPC" != "true" ]]; then
    warn "Skipping VPC deletion. Set DELETE_VPC=true and VPC_ID=<vpc-id> to delete the VPC too."
    return 0
  fi
  discover_vpc_id || fail "DELETE_VPC=true requires VPC_ID or an EKS cluster/VPC tagged with Project=$PROJECT_NAME"

  warn "Deleting VPC dependencies for $VPC_ID"

  mapfile -t classic_load_balancers < <(aws elb describe-load-balancers --region "$AWS_REGION" --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text | tr '\t' '\n')
  for lb in "${classic_load_balancers[@]}"; do
    [[ -z "$lb" ]] && continue
    warn "Deleting classic load balancer: $lb"
    aws elb delete-load-balancer --region "$AWS_REGION" --load-balancer-name "$lb" || true
  done

  mapfile -t load_balancers < <(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text | tr '\t' '\n')
  for lb in "${load_balancers[@]}"; do
    [[ -z "$lb" ]] && continue
    warn "Deleting load balancer: $lb"
    aws elbv2 delete-load-balancer --region "$AWS_REGION" --load-balancer-arn "$lb" || true
  done

  wait_for_load_balancers_deleted
  delete_nat_gateways_cli
  release_nat_gateway_eips_cli

  mapfile -t volumes < <(aws ec2 describe-volumes --region "$AWS_REGION" --filters "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned" --query 'Volumes[].VolumeId' --output text | tr '\t' '\n')
  for volume in "${volumes[@]}"; do
    [[ -z "$volume" ]] && continue
    warn "Deleting EBS volume: $volume"
    aws ec2 delete-volume --region "$AWS_REGION" --volume-id "$volume" || true
  done

  mapfile -t enis < <(aws ec2 describe-network-interfaces --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text | tr '\t' '\n')
  for eni in "${enis[@]}"; do
    [[ -z "$eni" ]] && continue
    attachment_id="$(aws ec2 describe-network-interfaces --region "$AWS_REGION" --network-interface-ids "$eni" --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text 2>/dev/null || true)"
    requester_managed="$(aws ec2 describe-network-interfaces --region "$AWS_REGION" --network-interface-ids "$eni" --query 'NetworkInterfaces[0].RequesterManaged' --output text 2>/dev/null || true)"
    if [[ -n "$attachment_id" && "$attachment_id" != "None" && "$requester_managed" != "true" ]]; then
      warn "Detaching network interface: $eni"
      aws ec2 detach-network-interface --region "$AWS_REGION" --attachment-id "$attachment_id" --force || true
      sleep 5
    fi
    warn "Deleting network interface: $eni"
    aws ec2 delete-network-interface --region "$AWS_REGION" --network-interface-id "$eni" || true
  done

  mapfile -t subnets < <(aws ec2 describe-subnets --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text | tr '\t' '\n')
  mapfile -t igws < <(aws ec2 describe-internet-gateways --region "$AWS_REGION" --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[].InternetGatewayId' --output text | tr '\t' '\n')
  mapfile -t security_groups < <(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text | tr '\t' '\n')
  mapfile -t route_tables < <(aws ec2 describe-route-tables --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[?Main!=true]].RouteTableId" --output text | tr '\t' '\n')

  for sg in "${security_groups[@]}"; do
    [[ -z "$sg" ]] && continue
    warn "Deleting security group: $sg"
    aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$sg" || true
  done

  for rt in "${route_tables[@]}"; do
    [[ -z "$rt" ]] && continue
    mapfile -t associations < <(aws ec2 describe-route-tables --region "$AWS_REGION" --route-table-ids "$rt" --query 'RouteTables[].Associations[?Main!=true].RouteTableAssociationId' --output text | tr '\t' '\n')
    for assoc in "${associations[@]}"; do
      [[ -z "$assoc" ]] && continue
      warn "Disassociating route table association: $assoc"
      aws ec2 disassociate-route-table --region "$AWS_REGION" --association-id "$assoc" || true
    done
    warn "Deleting route table: $rt"
    aws ec2 delete-route-table --region "$AWS_REGION" --route-table-id "$rt" || true
  done

  for igw in "${igws[@]}"; do
    [[ -z "$igw" ]] && continue
    warn "Detaching and deleting internet gateway: $igw"
    aws ec2 detach-internet-gateway --region "$AWS_REGION" --internet-gateway-id "$igw" --vpc-id "$VPC_ID" || true
    aws ec2 delete-internet-gateway --region "$AWS_REGION" --internet-gateway-id "$igw" || true
  done

  for subnet in "${subnets[@]}"; do
    [[ -z "$subnet" ]] && continue
    warn "Deleting subnet: $subnet"
    aws ec2 delete-subnet --region "$AWS_REGION" --subnet-id "$subnet" || true
  done

  for sg in "${security_groups[@]}"; do
    [[ -z "$sg" ]] && continue
    warn "Retrying security group deletion: $sg"
    aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$sg" || true
  done

  warn "Deleting VPC: $VPC_ID"
  aws ec2 delete-vpc --region "$AWS_REGION" --vpc-id "$VPC_ID"
  log "VPC $VPC_ID deleted"
}

cleanup_remaining_resources_cli() {
  step "Remaining Resource Cleanup Sweep"
  discover_vpc_id >/dev/null || true

  if [[ -n "$VPC_ID" ]]; then
    warn "Checking for remaining non-default resources in VPC $VPC_ID"

    mapfile -t classic_load_balancers < <(aws elb describe-load-balancers --region "$AWS_REGION" --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text | tr '\t' '\n')
    for lb in "${classic_load_balancers[@]}"; do
      [[ -z "$lb" ]] && continue
      warn "Removing remaining classic load balancer: $lb"
      aws elb delete-load-balancer --region "$AWS_REGION" --load-balancer-name "$lb" || true
    done

    mapfile -t load_balancers < <(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text | tr '\t' '\n')
    for lb in "${load_balancers[@]}"; do
      [[ -z "$lb" ]] && continue
      warn "Removing remaining v2 load balancer: $lb"
      aws elbv2 delete-load-balancer --region "$AWS_REGION" --load-balancer-arn "$lb" || true
    done
    wait_for_load_balancers_deleted
    delete_nat_gateways_cli
    release_nat_gateway_eips_cli

    mapfile -t volumes < <(aws ec2 describe-volumes --region "$AWS_REGION" --filters "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned" --query 'Volumes[].VolumeId' --output text | tr '\t' '\n')
    for volume in "${volumes[@]}"; do
      [[ -z "$volume" ]] && continue
      warn "Removing remaining cluster EBS volume: $volume"
      aws ec2 delete-volume --region "$AWS_REGION" --volume-id "$volume" || true
    done

    mapfile -t enis < <(aws ec2 describe-network-interfaces --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text | tr '\t' '\n')
    for eni in "${enis[@]}"; do
      [[ -z "$eni" ]] && continue
      attachment_id="$(aws ec2 describe-network-interfaces --region "$AWS_REGION" --network-interface-ids "$eni" --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text 2>/dev/null || true)"
      requester_managed="$(aws ec2 describe-network-interfaces --region "$AWS_REGION" --network-interface-ids "$eni" --query 'NetworkInterfaces[0].RequesterManaged' --output text 2>/dev/null || true)"
      if [[ -n "$attachment_id" && "$attachment_id" != "None" && "$requester_managed" != "true" ]]; then
        warn "Detaching remaining network interface: $eni"
        aws ec2 detach-network-interface --region "$AWS_REGION" --attachment-id "$attachment_id" --force || true
        sleep 5
      fi
      warn "Removing remaining network interface: $eni"
      aws ec2 delete-network-interface --region "$AWS_REGION" --network-interface-id "$eni" || true
    done

    mapfile -t route_tables < <(aws ec2 describe-route-tables --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[?Main!=true]].RouteTableId" --output text | tr '\t' '\n')
    for rt in "${route_tables[@]}"; do
      [[ -z "$rt" ]] && continue
      mapfile -t associations < <(aws ec2 describe-route-tables --region "$AWS_REGION" --route-table-ids "$rt" --query 'RouteTables[].Associations[?Main!=true].RouteTableAssociationId' --output text | tr '\t' '\n')
      for assoc in "${associations[@]}"; do
        [[ -z "$assoc" ]] && continue
        warn "Removing remaining route table association: $assoc"
        aws ec2 disassociate-route-table --region "$AWS_REGION" --association-id "$assoc" || true
      done
      warn "Removing remaining non-main route table: $rt"
      aws ec2 delete-route-table --region "$AWS_REGION" --route-table-id "$rt" || true
    done

    mapfile -t security_groups < <(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text | tr '\t' '\n')
    for sg in "${security_groups[@]}"; do
      [[ -z "$sg" ]] && continue
      warn "Removing remaining non-default security group: $sg"
      aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$sg" || true
    done

    mapfile -t subnets < <(aws ec2 describe-subnets --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text | tr '\t' '\n')
    for subnet in "${subnets[@]}"; do
      [[ -z "$subnet" ]] && continue
      warn "Removing remaining subnet: $subnet"
      aws ec2 delete-subnet --region "$AWS_REGION" --subnet-id "$subnet" || true
    done

    if [[ "$DELETE_VPC" == "true" ]]; then
      warn "Retrying VPC deletion after remaining-resource sweep: $VPC_ID"
      aws ec2 delete-vpc --region "$AWS_REGION" --vpc-id "$VPC_ID" || true
    fi
  fi

  warn "Checking for remaining ECR repositories"
  delete_ecr_repo_cli "$PROJECT_NAME/auth-service"
  delete_ecr_repo_cli "$PROJECT_NAME/user-service"
  delete_ecr_repo_cli "$PROJECT_NAME/task-service"
  delete_ecr_repo_cli "$PROJECT_NAME/frontend"

  if [[ "$DELETE_IAM_ROLES" == "true" ]]; then
    warn "Checking for remaining IAM roles"
    delete_iam_role_cli "${CLUSTER_NAME}-cluster-role"
    delete_iam_role_cli "${CLUSTER_NAME}-node-role"
  fi
}

print_remaining_resources_cli() {
  step "Remaining AWS Resource Check"
  if cluster_exists; then
    warn "EKS cluster still exists: $CLUSTER_NAME"
  else
    log "EKS cluster deleted: $CLUSTER_NAME"
  fi

  log "Remaining ECR repositories"
  aws ecr describe-repositories \
    --region "$AWS_REGION" \
    --query "repositories[?starts_with(repositoryName, '$PROJECT_NAME/')].repositoryName" \
    --output table || true

  if [[ -n "$VPC_ID" ]]; then
    log "Remaining classic load balancers in $VPC_ID"
    aws elb describe-load-balancers \
      --region "$AWS_REGION" \
      --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" \
      --output table || true

    log "Remaining v2 load balancers in $VPC_ID"
    aws elbv2 describe-load-balancers \
      --region "$AWS_REGION" \
      --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerName" \
      --output table || true

    log "Remaining NAT gateways in $VPC_ID"
    aws ec2 describe-nat-gateways \
      --region "$AWS_REGION" \
      --filter "Name=vpc-id,Values=$VPC_ID" \
      --query 'NatGateways[].{NatGatewayId:NatGatewayId,State:State,PublicIp:NatGatewayAddresses[0].PublicIp,AllocationId:NatGatewayAddresses[0].AllocationId}' \
      --output table || true

    log "Remaining Elastic IPs tagged or associated in $VPC_ID"
    aws ec2 describe-addresses \
      --region "$AWS_REGION" \
      --query "Addresses[?VpcId=='$VPC_ID' || Tags[?Key=='Project' && Value=='$PROJECT_NAME']].{AllocationId:AllocationId,PublicIp:PublicIp,AssociationId:AssociationId}" \
      --output table || true

    log "Remaining subnets in $VPC_ID"
    aws ec2 describe-subnets \
      --region "$AWS_REGION" \
      --filters "Name=vpc-id,Values=$VPC_ID" \
      --query 'Subnets[].SubnetId' \
      --output table || true

    log "Remaining security groups in $VPC_ID"
    aws ec2 describe-security-groups \
      --region "$AWS_REGION" \
      --filters "Name=vpc-id,Values=$VPC_ID" \
      --query "SecurityGroups[?GroupName!='default'].{GroupId:GroupId,Name:GroupName}" \
      --output table || true

    log "Skipped default VPC resources in $VPC_ID"
    aws ec2 describe-security-groups \
      --region "$AWS_REGION" \
      --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=default" \
      --query 'SecurityGroups[].{GroupId:GroupId,Name:GroupName}' \
      --output table || true
    aws ec2 describe-route-tables \
      --region "$AWS_REGION" \
      --filters "Name=vpc-id,Values=$VPC_ID" \
      --query 'RouteTables[?Associations[?Main==`true`]].{RouteTableId:RouteTableId,Main:Associations[0].Main}' \
      --output table || true
  fi

  log "Relevant IAM role status"
  aws iam get-role --role-name "${CLUSTER_NAME}-cluster-role" --query 'Role.RoleName' --output text 2>/dev/null || true
  aws iam get-role --role-name "${CLUSTER_NAME}-node-role" --query 'Role.RoleName' --output text 2>/dev/null || true
}

delete_iam_role_cli() {
  local role="$1"
  if ! aws iam get-role --role-name "$role" >/dev/null 2>&1; then
    warn "IAM role not found: $role"
    return 0
  fi

  warn "Cleaning IAM role: $role"
  mapfile -t attached_policies < <(aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text | tr '\t' '\n')
  for policy_arn in "${attached_policies[@]}"; do
    [[ -z "$policy_arn" ]] && continue
    log "Detaching policy from $role: $policy_arn"
    aws iam detach-role-policy --role-name "$role" --policy-arn "$policy_arn" || true
  done

  mapfile -t inline_policies < <(aws iam list-role-policies --role-name "$role" --query 'PolicyNames[]' --output text | tr '\t' '\n')
  for policy_name in "${inline_policies[@]}"; do
    [[ -z "$policy_name" ]] && continue
    log "Deleting inline policy from $role: $policy_name"
    aws iam delete-role-policy --role-name "$role" --policy-name "$policy_name" || true
  done

  warn "Deleting IAM role: $role"
  aws iam delete-role --role-name "$role" || true
}

delete_iam_roles_cli() {
  step "IAM Cleanup via AWS CLI"
  if [[ "$DELETE_IAM_ROLES" != "true" ]]; then
    warn "Skipping IAM role deletion because DELETE_IAM_ROLES=$DELETE_IAM_ROLES"
    return 0
  fi

  delete_iam_role_cli "${CLUSTER_NAME}-cluster-role"
  delete_iam_role_cli "${CLUSTER_NAME}-node-role"
}

destroy_aws_cli_stack() {
  step "AWS CLI Stack Destroy"
  warn "Terraform is not available or CLEANUP_BACKEND=aws-cli. Falling back to AWS CLI teardown."
  discover_vpc_id >/dev/null || true
  delete_kubernetes_namespace_cli
  delete_eks_addons_cli
  delete_eks_nodegroups_cli
  delete_eks_cluster_cli
  delete_ecr_repos_cli
  delete_vpc_cli
  delete_iam_roles_cli
  cleanup_remaining_resources_cli
  print_remaining_resources_cli
}

select_cleanup_backend() {
  case "$CLEANUP_BACKEND" in
    auto)
      if has_cmd terraform; then
        printf '%s\n' terraform
      else
        printf '%s\n' aws-cli
      fi
      ;;
    terraform | aws-cli)
      printf '%s\n' "$CLEANUP_BACKEND"
      ;;
    *)
      fail "Unsupported CLEANUP_BACKEND '$CLEANUP_BACKEND'. Use 'auto', 'terraform', or 'aws-cli'."
      ;;
  esac
}

wait_for_cluster_deleted() {
  step "Final AWS Status"
  local deadline=$((SECONDS + WAIT_TIMEOUT_SECONDS))

  if ! cluster_exists; then
    log "EKS cluster $CLUSTER_NAME is deleted"
    return 0
  fi

  warn "Waiting for EKS cluster $CLUSTER_NAME to disappear from AWS"
  until ! cluster_exists; do
    if (( SECONDS >= deadline )); then
      fail "Timed out waiting for EKS cluster deletion after ${WAIT_TIMEOUT_SECONDS}s"
    fi

    local status
    status="$(aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" --query 'cluster.status' --output text 2>/dev/null || true)"
    log "Current EKS cluster status: ${status:-not-found}"
    sleep 20
  done

  log "EKS cluster $CLUSTER_NAME is deleted"
}

final_summary() {
  local finished_at
  finished_at="$(date +%s)"
  step "Cleanup Summary"
  log "Mode: $CLEANUP_MODE"
  log "Region: $AWS_REGION"
  log "Cluster: $CLUSTER_NAME"
  log "Namespace: $KUBE_NAMESPACE"
  log "Cleanup backend: $(select_cleanup_backend)"
  log "Terraform directory: $TF_DIR"
  log "Elapsed seconds: $((finished_at - started_at))"
}

need_cmd aws
need_cmd kubectl

case "$CLEANUP_MODE" in
  full-stack | terraform-destroy | destroy-eks)
    confirm_destructive_action
    print_aws_status
    print_k8s_status
    print_terraform_status
    cleanup_backend="$(select_cleanup_backend)"
    if [[ "$cleanup_backend" == "terraform" ]]; then
      empty_ecr_repos
      disable_kubernetes_workloads
      destroy_terraform_stack
      wait_for_cluster_deleted
      print_remaining_resources_cli
    else
      destroy_aws_cli_stack
    fi
    final_summary
    ;;
  status)
    print_aws_status
    print_k8s_status
    print_terraform_status
    final_summary
    ;;
  *)
    fail "Unsupported CLEANUP_MODE '$CLEANUP_MODE'. Use 'status' or 'full-stack'."
    ;;
esac
