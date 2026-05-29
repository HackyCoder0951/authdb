#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${TERRAFORM_DIR:-${REPO_ROOT}/terraform/aws-eks}"
GENERATED_AT="$(date -u +"%Y-%m-%d %H:%M:%SZ")"

tf_output() {
  local name="$1"
  local default_value="$2"

  terraform -chdir="${TERRAFORM_DIR}" output -raw "${name}" 2>/dev/null || printf '%s' "${default_value}"
}

cluster_name="$(tf_output cluster_name authdb-prod)"
aws_region="$(tf_output aws_region us-east-1)"
vpc_id="$(tf_output vpc_id vpc-pending)"
frontend_lb="$(tf_output frontend_load_balancer_hostname pending)"
auth_repo="$(tf_output auth_service_ecr_repository_url auth-service-ecr)"
user_repo="$(tf_output user_service_ecr_repository_url user-service-ecr)"
task_repo="$(tf_output task_service_ecr_repository_url task-service-ecr)"
frontend_repo="$(tf_output frontend_ecr_repository_url frontend-ecr)"

cat <<EOF
# AuthDB AWS Architecture

Generated from Terraform outputs on ${GENERATED_AT}.

## Current Deployment Facts
- AWS region: ${aws_region}
- EKS cluster: ${cluster_name}
- VPC: ${vpc_id}
- Frontend load balancer: ${frontend_lb}
- ECR repositories:
  - ${auth_repo}
  - ${user_repo}
  - ${task_repo}
  - ${frontend_repo}

## AWS Deployment Topology

```mermaid
graph TD
    Browser[Browser / User] --> LB[Public AWS Load Balancer]
    LB --> FrontendSvc[Kubernetes Service: frontend]
    FrontendSvc --> FrontendPod[Frontend Deployment]

    FrontendPod --> GatewaySvc[Kubernetes Service: gateway]
    GatewaySvc --> GatewayPod[Gateway Deployment]

    GatewayPod --> AuthSvc[Kubernetes Service: auth-service]
    GatewayPod --> UserSvc[Kubernetes Service: user-service]
    GatewayPod --> TaskSvc[Kubernetes Service: task-service]

    AuthSvc --> AuthPod[auth-service Deployment]
    UserSvc --> UserPod[user-service Deployment]
    TaskSvc --> TaskPod[task-service Deployment]

    AuthPod --> MongoSvc[Kubernetes Service: mongodb]
    UserPod --> MongoSvc
    TaskPod --> MongoSvc

    AuthPod --> RabbitSvc[Kubernetes Service: rabbitmq]
    UserPod --> RabbitSvc
    TaskPod --> RabbitSvc

    subgraph AWS_Foundation[AWS Foundation]
        VPC[VPC: ${vpc_id}]
        IGW[Internet Gateway]
        RT[Public Route Table]
        Subnets[2 Public Subnets]
        EKS[EKS Cluster: ${cluster_name}]
        Nodes[EKS Managed Node Group: m7i-flex.large]
        ECR[ECR Repositories]
    end

    subgraph K8S[Kubernetes Namespace: authdb]
        Namespace[Namespace]
        Secret[Secret]
        ConfigMap[ConfigMap]
        PVC[PVC: mongodb-data]
        HPA[Optional HPA]
    end

    VPC --> Subnets --> RT --> IGW
    Subnets --> EKS --> Nodes --> Namespace
    Namespace --> Secret
    Namespace --> ConfigMap
    Namespace --> PVC
    Namespace --> HPA

    ECR --> FrontendPod
    ECR --> GatewayPod
    ECR --> AuthPod
    ECR --> UserPod
    ECR --> TaskPod
```

## Terraform Layer Map

| Layer | Terraform files | Purpose |
| --- | --- | --- |
| Network | `networking.tf`, `variables.tf` | VPC, subnets, routing, and CIDR settings |
| Identity and compute | `iam.tf`, `eks.tf` | IAM roles, EKS cluster, node group, and add-ons |
| Container registry | `ecr.tf`, `outputs.tf` | ECR repositories and image login outputs |
| Kubernetes base | `kubernetes.tf` | Namespace, Secret, ConfigMap, and PVC |
| Kubernetes workloads | `kubernetes-apps.tf`, `kubernetes-services.tf` | Deployments, Services, and HPA |

## Workflow

1. Run Terraform in `terraform/aws-eks` to create or update the AWS foundation.
2. Build and push images using the ECR URLs that Terraform outputs.
3. Re-apply with Kubernetes enabled to create the runtime workloads.
4. Regenerate this Markdown summary whenever the Terraform outputs or topology change.
EOF