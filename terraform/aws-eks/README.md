# AuthDB Terraform AWS EKS Deployment

This Terraform stack creates a cost-aware AWS Kubernetes deployment for AuthDB:

- VPC with two public subnets
- Internet gateway and public route table
- EKS cluster
- One EKS managed node group using only `m7i-flex.large`
- ECR repositories for project images
- Optional Kubernetes workloads for frontend, gateway, FastAPI services, MongoDB, RabbitMQ, PVC, services, and HPA

The worker node group is intentionally restricted to:

```text
m7i-flex.large
```

Do not add fallback instance types if your requirement is to use `--instance-types m7i-flex.large only`.

## Why Two Applies?

Terraform creates ECR repositories and EKS first. The app images must then be built and pushed to ECR before Kubernetes deployments are created.

Workflow:

1. Apply AWS infrastructure and ECR repos.
2. Build and push Docker images.
3. Apply Kubernetes workloads.

## Prerequisites

Install:

- Terraform `>= 1.6`
- AWS CLI
- Docker
- kubectl

Authenticate AWS:

```bash
aws configure
aws sts get-caller-identity
```

Check whether `m7i-flex.large` is available in your target region:

```bash
aws ec2 describe-instance-type-offerings \
  --location-type availability-zone \
  --filters Name=instance-type,Values=m7i-flex.large \
  --region us-east-1
```

Check trial/free-credit quota before applying:

```bash
aws service-quotas list-service-quotas --service-code eks --region us-east-1
aws service-quotas list-service-quotas --service-code ec2 --region us-east-1
```

## Step 1: Configure Terraform

From repo root:

```bash
cd terraform/aws-eks
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` if needed:

```hcl
aws_region   = "us-east-1"
cluster_name = "authdb-prod"
image_tag    = "v1"

node_desired_size = 1
node_min_size     = 1
node_max_size     = 2

deploy_kubernetes = false
```

For better security, restrict the EKS API endpoint to your IP:

```hcl
cluster_endpoint_public_access_cidrs = ["YOUR_PUBLIC_IP/32"]
```

## Step 2: Create AWS Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

This creates:

- VPC
- Subnets
- EKS cluster
- EKS node group with only `m7i-flex.large`
- ECR repositories

Configure kubectl:

```bash
aws eks update-kubeconfig --region $(terraform output -raw aws_region) --name $(terraform output -raw cluster_name)
kubectl get nodes
```

Expected:

```text
One Ready node with instance type m7i-flex.large.
```

## Step 3: Build and Push Images

Use the helper script:

```bash
cd terraform/aws-eks
IMAGE_TAG=v1 ./build-and-push.sh
```

Or run the steps manually.

Login to ECR:

```bash
terraform output -raw docker_login_command
```

Run the printed command, then build and push from the repository root:

```bash
cd ../..

IMAGE_TAG=v1

AUTH_REPO=$(terraform -chdir=terraform/aws-eks output -raw auth_service_ecr_repository_url)
USER_REPO=$(terraform -chdir=terraform/aws-eks output -raw user_service_ecr_repository_url)
TASK_REPO=$(terraform -chdir=terraform/aws-eks output -raw task_service_ecr_repository_url)
FRONTEND_REPO=$(terraform -chdir=terraform/aws-eks output -raw frontend_ecr_repository_url)

docker build -f services/auth-services/Dockerfile -t ${AUTH_REPO}:${IMAGE_TAG} .
docker build -f services/user-services/Dockerfile -t ${USER_REPO}:${IMAGE_TAG} .
docker build -f services/tasks-services/Dockerfile -t ${TASK_REPO}:${IMAGE_TAG} .
docker build -f frontend/Dockerfile -t ${FRONTEND_REPO}:${IMAGE_TAG} .

docker push ${AUTH_REPO}:${IMAGE_TAG}
docker push ${USER_REPO}:${IMAGE_TAG}
docker push ${TASK_REPO}:${IMAGE_TAG}
docker push ${FRONTEND_REPO}:${IMAGE_TAG}
```

## Step 4: Deploy Kubernetes Workloads

Edit `terraform.tfvars`:

```hcl
deploy_kubernetes = true
```

Apply again:

```bash
cd terraform/aws-eks
terraform plan
terraform apply
```

Check the workloads:

```bash
kubectl get pods -n authdb
kubectl get svc -n authdb
kubectl get pvc -n authdb
```

Get the frontend URL:

```bash
terraform output frontend_load_balancer_hostname
```

If the output is still null, wait and check the service:

```bash
kubectl get svc frontend -n authdb --watch
```

## Step 5: Smoke Test

Test API health through the private gateway service:

```bash
kubectl port-forward svc/gateway 8081:80 -n authdb
curl http://localhost:8081/api/v1/health
curl http://localhost:8081/api/v1/health/auth
curl http://localhost:8081/api/v1/health/users
curl http://localhost:8081/api/v1/health/tasks
```

Open the frontend load balancer hostname in your browser and test:

- Register
- Login
- Create a task
- View task list

## Cost Notes for a $100 Credit Account

This stack defaults to one `m7i-flex.large` worker node to reduce cost. It still creates billable AWS resources:

- EKS control plane
- EC2 worker node
- EBS volumes
- Elastic Load Balancer
- ECR storage

Destroy resources when you are done testing:

```bash
terraform destroy
```

## Cleanup

If Kubernetes resources were deployed:

```bash
terraform apply -var="deploy_kubernetes=false"
```

Then destroy AWS infrastructure:

```bash
terraform destroy
```

## Files

```text
versions.tf
providers.tf
variables.tf
locals.tf
random.tf
networking.tf
iam.tf
ecr.tf
eks.tf
kubernetes.tf
kubernetes-apps.tf
kubernetes-services.tf
outputs.tf
terraform.tfvars.example
build-and-push.sh
```
