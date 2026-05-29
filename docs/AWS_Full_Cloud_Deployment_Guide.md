# AWS Full Cloud Deployment Guide

Date: 28 May 2026

This is a step-by-step AWS cloud deployment runbook for the full AuthDB project using Kubernetes on Amazon EKS.

It includes the practical checks to complete before launching worker instances or deploying workloads: AWS account access, IAM, region, VPC, subnets, route tables, NAT, internet gateway, security groups, storage, load balancers, DNS, ECR images, and Kubernetes rollout.

## 1. What Will Be Deployed

Application components:

- React frontend, served by Nginx on port `80`
- Nginx API gateway on port `80`
- Auth FastAPI service on port `8001`
- User FastAPI service on port `8002`
- Task FastAPI service on port `8003`
- MongoDB on port `27017`
- RabbitMQ on ports `5672` and `15672`

AWS components:

- Amazon EKS cluster
- EC2 managed node group for Kubernetes worker nodes
- Amazon ECR repositories for app images
- VPC with public and private subnets
- Route tables, internet gateway, and NAT gateway or VPC endpoints
- Security groups for cluster, nodes, and load balancer traffic
- EBS-backed PersistentVolumeClaim for MongoDB
- Load balancer or ingress controller for public access
- Optional Route 53 DNS and TLS certificate

Recommended production shape:

```text
Internet
  -> AWS Load Balancer or Ingress
  -> frontend Service
  -> frontend Nginx
  -> gateway Service
  -> auth-service / user-service / task-service
  -> MongoDB and RabbitMQ inside private cluster network
```

## 2. Local Prerequisites

Install these on your deployment machine:

- AWS CLI v2
- Docker
- kubectl
- eksctl
- Helm
- Git
- openssl

Check the tools:

```bash
aws --version
docker --version
kubectl version --client
eksctl version
helm version
git --version
openssl version
```

Authenticate to AWS:

```bash
aws configure
aws sts get-caller-identity
```

Expected result:

- You can see the AWS account ID.
- The account is the correct target account.
- The caller identity is an IAM user or role that is allowed to create EKS, ECR, EC2, IAM, VPC, CloudFormation, EBS, and load balancer resources.

## 3. Deployment Variables

Set common variables:

```bash
export AWS_REGION=us-east-1
export CLUSTER_NAME=authdb-prod
export NAMESPACE=authdb
export IMAGE_TAG=v1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
```

Confirm them:

```bash
echo $AWS_REGION
echo $CLUSTER_NAME
echo $AWS_ACCOUNT_ID
echo $ECR_REGISTRY
```

## 4. AWS Account and Region Preflight

Check active region:

```bash
aws configure get region
aws ec2 describe-availability-zones --region $AWS_REGION --query 'AvailabilityZones[].ZoneName'
```

Check service availability:

- EKS is available in the chosen region.
- ECR is available in the chosen region.
- At least two Availability Zones are available.
- Your organization policies allow EKS, EC2, ECR, IAM, and load balancer creation.

Check quotas before creating resources:

```bash
aws service-quotas list-service-quotas --service-code ec2 --region $AWS_REGION
aws service-quotas list-service-quotas --service-code eks --region $AWS_REGION
aws service-quotas list-service-quotas --service-code elasticloadbalancing --region $AWS_REGION
```

Minimum practical capacity for this project:

- 1 EKS cluster
- 3 worker nodes
- At least 6 vCPUs available for EC2 instances
- 1 public load balancer
- 1 EBS volume for MongoDB
- Enough free private subnet IP addresses for nodes and pods

## 5. IAM Preflight

The deploying identity must be able to create:

- EKS cluster
- EKS managed node group
- IAM roles and policies
- EC2 security groups, instances, ENIs, and launch templates
- ECR repositories and image pushes
- EBS volumes through the EBS CSI driver
- Load balancers, target groups, and listeners if using ingress or LoadBalancer services

Check caller identity:

```bash
aws sts get-caller-identity
```

Recommended IAM setup:

- Use an admin or platform-engineering role for initial cluster creation.
- Use a narrower CI/CD role for image build and deployment after the first setup.
- Enable IAM OIDC provider for the cluster if installing controllers such as the AWS Load Balancer Controller or EBS CSI driver with IRSA.

## 6. Network Design Decision

Choose one network path before launching EKS.

Option A: Create a new VPC for this project.

- Best for labs, demos, and clean production foundations.
- Easier because eksctl can create subnets, route tables, and required tags.
- Recommended if you do not already have a compliant VPC.

Option B: Use an existing VPC.

- Best when your company already has approved networking.
- Requires more preflight checks.
- You must confirm subnet tags, routes, IP capacity, and security rules.

Recommended VPC layout:

- One VPC across at least two Availability Zones.
- Public subnets for load balancers and NAT gateways.
- Private subnets for EKS worker nodes.
- Internet gateway attached to the VPC.
- NAT gateway for private subnet outbound internet access, or VPC endpoints for private pulls and AWS API access.
- DNS resolution and DNS hostnames enabled.

## 7. Existing VPC Checklist

List VPCs:

```bash
aws ec2 describe-vpcs \
  --region $AWS_REGION \
  --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,State:State,IsDefault:IsDefault}'
```

Set your VPC ID:

```bash
export VPC_ID=vpc-xxxxxxxxxxxxxxxxx
```

Check VPC DNS settings:

```bash
aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsSupport --region $AWS_REGION
aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsHostnames --region $AWS_REGION
```

Expected:

```text
enableDnsSupport = true
enableDnsHostnames = true
```

List subnets:

```bash
aws ec2 describe-subnets \
  --filters Name=vpc-id,Values=$VPC_ID \
  --region $AWS_REGION \
  --query 'Subnets[].{SubnetId:SubnetId,AZ:AvailabilityZone,Cidr:CidrBlock,AvailableIPs:AvailableIpAddressCount,PublicIpOnLaunch:MapPublicIpOnLaunch}'
```

Expected:

- At least two public subnets in different Availability Zones.
- At least two private subnets in different Availability Zones.
- Enough available IPs. For this project, keep at least 30 available IPs per private subnet for a small cluster.

Check internet gateway:

```bash
aws ec2 describe-internet-gateways \
  --filters Name=attachment.vpc-id,Values=$VPC_ID \
  --region $AWS_REGION
```

Expected:

- One internet gateway attached to the VPC.

Check route tables:

```bash
aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values=$VPC_ID \
  --region $AWS_REGION \
  --query 'RouteTables[].{RouteTableId:RouteTableId,Associations:Associations[].SubnetId,Routes:Routes}'
```

Expected for public subnets:

- Route to local VPC CIDR.
- Route `0.0.0.0/0` to an internet gateway, for example `igw-...`.

Expected for private subnets:

- Route to local VPC CIDR.
- Route `0.0.0.0/0` to a NAT gateway, for example `nat-...`, or required VPC endpoints if running private-only.

Check NAT gateways:

```bash
aws ec2 describe-nat-gateways \
  --filter Name=vpc-id,Values=$VPC_ID \
  --region $AWS_REGION \
  --query 'NatGateways[].{NatGatewayId:NatGatewayId,State:State,SubnetId:SubnetId}'
```

Expected:

- At least one NAT gateway in `available` state if private nodes need outbound internet access.

## 8. Required Subnet Tags

EKS and Kubernetes load balancers depend on subnet discovery tags.

For every subnet used by the cluster:

```text
kubernetes.io/cluster/authdb-prod = shared
```

For public load balancer subnets:

```text
kubernetes.io/role/elb = 1
```

For private/internal load balancer subnets:

```text
kubernetes.io/role/internal-elb = 1
```

Check current subnet tags:

```bash
aws ec2 describe-subnets \
  --filters Name=vpc-id,Values=$VPC_ID \
  --region $AWS_REGION \
  --query 'Subnets[].{SubnetId:SubnetId,Tags:Tags}'
```

Add tags if needed:

```bash
aws ec2 create-tags \
  --resources subnet-aaaaaaaaaaaaaaaaa subnet-bbbbbbbbbbbbbbbbb \
  --tags Key=kubernetes.io/cluster/$CLUSTER_NAME,Value=shared \
  --region $AWS_REGION

aws ec2 create-tags \
  --resources subnet-publicaaaa subnet-publicbbbb \
  --tags Key=kubernetes.io/role/elb,Value=1 \
  --region $AWS_REGION

aws ec2 create-tags \
  --resources subnet-privateaaaa subnet-privatebbbb \
  --tags Key=kubernetes.io/role/internal-elb,Value=1 \
  --region $AWS_REGION
```

## 9. Security Group Preflight

Security group plan:

- Load balancer security group allows public inbound `80` and `443`.
- EKS worker node security group allows required cluster and node communication.
- Application pods do not need public security group access.
- MongoDB and RabbitMQ must not be public.
- SSH port `22` should stay closed. Use AWS Systems Manager Session Manager if node access is required.

List security groups:

```bash
aws ec2 describe-security-groups \
  --filters Name=vpc-id,Values=$VPC_ID \
  --region $AWS_REGION \
  --query 'SecurityGroups[].{GroupId:GroupId,Name:GroupName,Description:Description}'
```

Check a specific security group:

```bash
export SG_ID=sg-xxxxxxxxxxxxxxxxx

aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --region $AWS_REGION
```

Minimum public load balancer rules:

```text
Inbound:
80/tcp from 0.0.0.0/0
443/tcp from 0.0.0.0/0

Outbound:
All traffic to worker nodes or VPC CIDR
```

Recommended worker node rules:

```text
Inbound:
Allow node-to-node traffic from the node security group.
Allow load balancer traffic to NodePort ranges when using instance targets.
Allow cluster control plane traffic as configured by EKS.

Outbound:
Allow HTTPS 443 to AWS APIs and internet through NAT, or to VPC endpoints.
Allow required traffic to ECR, EKS, STS, CloudWatch, and S3.
Allow internal traffic to MongoDB, RabbitMQ, and app services through Kubernetes networking.
```

Do not add public inbound access for:

- MongoDB `27017`
- RabbitMQ `5672`
- RabbitMQ management UI `15672`
- FastAPI service ports `8001`, `8002`, `8003`

## 10. Network ACL Preflight

If your VPC uses restrictive network ACLs, check them before launching nodes:

```bash
aws ec2 describe-network-acls \
  --filters Name=vpc-id,Values=$VPC_ID \
  --region $AWS_REGION
```

Expected:

- Public subnet NACLs allow inbound `80` and `443`.
- Private subnet NACLs allow return traffic using ephemeral ports.
- Private subnet NACLs allow node communication across the VPC CIDR.
- NACLs do not block DNS, HTTPS, container image pulls, or Kubernetes pod traffic.

## 11. Create the EKS Cluster

### Option A: New VPC Created by eksctl

This is the simplest path:

```bash
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --managed \
  --nodes 3 \
  --node-type t3.medium \
  --node-volume-size 40
```

eksctl creates:

- VPC
- Public and private subnets
- Route tables
- Internet gateway
- NAT gateway
- EKS control plane
- Managed node group
- Required IAM roles

### Option B: Existing VPC

Create `eksctl-authdb-existing-vpc.yml` outside production secrets:

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: authdb-prod
  region: us-east-1

vpc:
  id: vpc-xxxxxxxxxxxxxxxxx
  subnets:
    private:
      us-east-1a:
        id: subnet-privateaaaa
      us-east-1b:
        id: subnet-privatebbbb
    public:
      us-east-1a:
        id: subnet-publicaaaa
      us-east-1b:
        id: subnet-publicbbbb

managedNodeGroups:
  - name: authdb-workers
    instanceType: t3.medium
    desiredCapacity: 3
    minSize: 2
    maxSize: 5
    volumeSize: 40
    privateNetworking: true
```

Create the cluster:

```bash
eksctl create cluster -f eksctl-authdb-existing-vpc.yml
```

Update kubeconfig:

```bash
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
kubectl get nodes
```

Expected:

- All nodes show `Ready`.
- Nodes are spread across at least two Availability Zones.

## 12. Install or Verify EKS Add-ons

Check add-ons:

```bash
aws eks list-addons --cluster-name $CLUSTER_NAME --region $AWS_REGION
kubectl get pods -n kube-system
```

Recommended add-ons:

- VPC CNI
- CoreDNS
- kube-proxy
- EBS CSI driver
- metrics-server

Install metrics-server if not available:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Enable or verify EBS CSI driver:

```bash
aws eks describe-addon \
  --cluster-name $CLUSTER_NAME \
  --addon-name aws-ebs-csi-driver \
  --region $AWS_REGION
```

If it is missing, install it using the EKS console, AWS CLI, eksctl, or your infrastructure-as-code tool.

Confirm storage classes:

```bash
kubectl get storageclass
```

Expected:

- A default EBS-backed StorageClass is available, or you know which StorageClass to use for MongoDB.

## 13. Create ECR Repositories

Create repositories:

```bash
aws ecr create-repository --repository-name authdb/auth-service --region $AWS_REGION
aws ecr create-repository --repository-name authdb/user-service --region $AWS_REGION
aws ecr create-repository --repository-name authdb/task-service --region $AWS_REGION
aws ecr create-repository --repository-name authdb/frontend --region $AWS_REGION
```

Log Docker in:

```bash
aws ecr get-login-password --region $AWS_REGION \
  | docker login --username AWS --password-stdin $ECR_REGISTRY
```

## 14. Build and Push Images

Run from the repository root:

```bash
docker build -f services/auth-services/Dockerfile \
  -t $ECR_REGISTRY/authdb/auth-service:$IMAGE_TAG .

docker build -f services/user-services/Dockerfile \
  -t $ECR_REGISTRY/authdb/user-service:$IMAGE_TAG .

docker build -f services/tasks-services/Dockerfile \
  -t $ECR_REGISTRY/authdb/task-service:$IMAGE_TAG .

docker build -f frontend/Dockerfile \
  -t $ECR_REGISTRY/authdb/frontend:$IMAGE_TAG .
```

Push:

```bash
docker push $ECR_REGISTRY/authdb/auth-service:$IMAGE_TAG
docker push $ECR_REGISTRY/authdb/user-service:$IMAGE_TAG
docker push $ECR_REGISTRY/authdb/task-service:$IMAGE_TAG
docker push $ECR_REGISTRY/authdb/frontend:$IMAGE_TAG
```

## 15. Prepare Project Secrets

The Kubernetes secret file is:

```text
k8s/secret.yml
```

Replace demo values before deployment:

```yaml
stringData:
  SECRET_KEY: replace-with-openssl-rand-hex-32
  RABBITMQ_DEFAULT_USER: replace-me
  RABBITMQ_DEFAULT_PASS: replace-me
  MONGODB_ROOT_USER: replace-me
  MONGODB_ROOT_PASSWORD: replace-me
  MONGODB_DB: auth_scaleDB
```

Generate a JWT secret:

```bash
openssl rand -hex 32
```

Production recommendation:

- Do not store real secrets in Git.
- Use AWS Secrets Manager and External Secrets Operator for a production system.
- Rotate any credentials that were committed or shared.

## 16. Update Kubernetes Image References

Update image names in:

```text
k8s/auth-service-deployment.yml
k8s/user-service-deployment.yml
k8s/task-service-deployment.yml
k8s/frontend-deployment.yml
```

Use these ECR image formats:

```yaml
image: <account-id>.dkr.ecr.<region>.amazonaws.com/authdb/auth-service:v1
image: <account-id>.dkr.ecr.<region>.amazonaws.com/authdb/user-service:v1
image: <account-id>.dkr.ecr.<region>.amazonaws.com/authdb/task-service:v1
image: <account-id>.dkr.ecr.<region>.amazonaws.com/authdb/frontend:v1
```

The gateway deployment can keep:

```yaml
image: nginx:1.27-alpine
```

because the gateway config is loaded from `k8s/configmap.yml`.

## 17. Review Service Exposure Before Applying

Current `k8s/service.yml` defines:

- `frontend` as `ClusterIP`
- `gateway` as `LoadBalancer`
- backend services as `ClusterIP`

Recommended production exposure:

- Public: expose only `frontend` through Ingress or a LoadBalancer.
- Private: keep `gateway`, `auth-service`, `user-service`, `task-service`, `mongodb`, and `rabbitmq` as `ClusterIP`.

Before deployment, either:

1. Change `gateway` service type from `LoadBalancer` to `ClusterIP`, or
2. Deploy first, then patch it:

```bash
kubectl patch svc gateway -n $NAMESPACE -p '{"spec":{"type":"ClusterIP"}}'
```

To expose the frontend directly:

```bash
kubectl patch svc frontend -n $NAMESPACE -p '{"spec":{"type":"LoadBalancer"}}'
```

For a production domain and TLS, use an ingress controller instead of exposing raw services.

## 18. Deploy Kubernetes Manifests

Apply in order:

```bash
kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/secret.yml
kubectl apply -f k8s/configmap.yml
kubectl apply -f k8s/mongodb-persistent-volume.yml
kubectl apply -f k8s/rabbitmq-deployment.yml
kubectl apply -f k8s/auth-service-deployment.yml
kubectl apply -f k8s/user-service-deployment.yml
kubectl apply -f k8s/task-service-deployment.yml
kubectl apply -f k8s/gateway-deployment.yml
kubectl apply -f k8s/frontend-deployment.yml
kubectl apply -f k8s/service.yml
kubectl apply -f k8s/hpa.yml
```

Watch rollout:

```bash
kubectl get pods -n $NAMESPACE --watch
```

Check rollout status:

```bash
kubectl rollout status deployment/mongodb -n $NAMESPACE
kubectl rollout status deployment/rabbitmq -n $NAMESPACE
kubectl rollout status deployment/auth-service -n $NAMESPACE
kubectl rollout status deployment/user-service -n $NAMESPACE
kubectl rollout status deployment/task-service -n $NAMESPACE
kubectl rollout status deployment/gateway -n $NAMESPACE
kubectl rollout status deployment/frontend -n $NAMESPACE
```

## 19. Configure Public Access

### Simple Path: Frontend LoadBalancer

Patch frontend service:

```bash
kubectl patch svc frontend -n $NAMESPACE -p '{"spec":{"type":"LoadBalancer"}}'
```

Wait for the external hostname:

```bash
kubectl get svc frontend -n $NAMESPACE --watch
```

Open the load balancer hostname in a browser.

### Production Path: Ingress

If using the existing `k8s/ingress.yml`, install Nginx Ingress Controller because the manifest uses:

```yaml
ingressClassName: nginx
```

Then apply:

```bash
kubectl apply -f k8s/ingress.yml
kubectl get ingress -n $NAMESPACE
```

For AWS ALB ingress, install AWS Load Balancer Controller and create an ALB-compatible ingress manifest with ALB annotations.

## 20. DNS and TLS

For production:

1. Create or use a Route 53 hosted zone.
2. Create an ACM certificate for the domain.
3. Attach the certificate to the ALB or ingress load balancer.
4. Create a DNS record pointing to the load balancer hostname.

Example DNS plan:

```text
authdb.example.com -> frontend/ingress load balancer
```

Do not expose internal service hostnames publicly.

## 21. Verification Commands

Cluster:

```bash
kubectl get nodes -o wide
kubectl get pods -n $NAMESPACE -o wide
kubectl get svc -n $NAMESPACE
kubectl get pvc -n $NAMESPACE
kubectl get hpa -n $NAMESPACE
```

Events:

```bash
kubectl get events -n $NAMESPACE --sort-by=.lastTimestamp
```

Logs:

```bash
kubectl logs deployment/auth-service -n $NAMESPACE
kubectl logs deployment/user-service -n $NAMESPACE
kubectl logs deployment/task-service -n $NAMESPACE
kubectl logs deployment/gateway -n $NAMESPACE
kubectl logs deployment/frontend -n $NAMESPACE
```

Private API test:

```bash
kubectl port-forward svc/gateway 8081:80 -n $NAMESPACE
curl http://localhost:8081/api/v1/health
curl http://localhost:8081/api/v1/health/auth
curl http://localhost:8081/api/v1/health/users
curl http://localhost:8081/api/v1/health/tasks
```

Frontend test:

```bash
kubectl port-forward svc/frontend 8080:80 -n $NAMESPACE
```

Open:

```text
http://localhost:8080
```

End-to-end test:

1. Open the frontend URL.
2. Register a user.
3. Log in.
4. Create a task.
5. Confirm task list loads.
6. Check service health UI.

## 22. Troubleshooting Checklist

Pods stuck in `Pending`:

```bash
kubectl describe pod <pod-name> -n $NAMESPACE
kubectl describe pvc mongodb-data -n $NAMESPACE
kubectl get storageclass
```

Likely causes:

- No worker node capacity.
- No default StorageClass.
- EBS CSI driver missing.
- Subnets do not have enough free IPs.

Image pull failures:

```bash
kubectl describe pod <pod-name> -n $NAMESPACE
```

Likely causes:

- Wrong ECR image URI.
- Image tag not pushed.
- Worker node IAM role cannot pull from ECR.
- ECR repository is in a different region.

Load balancer not created:

```bash
kubectl describe svc frontend -n $NAMESPACE
kubectl describe ingress authdb-ingress -n $NAMESPACE
kubectl get events -n $NAMESPACE --sort-by=.lastTimestamp
```

Likely causes:

- Missing subnet tags.
- Public subnets not routed to internet gateway.
- AWS Load Balancer Controller missing when using ALB ingress.
- Security group or IAM permissions blocked.

Backend API fails:

```bash
kubectl get endpoints -n $NAMESPACE
kubectl logs deployment/gateway -n $NAMESPACE
kubectl logs deployment/auth-service -n $NAMESPACE
```

Likely causes:

- Gateway service has no endpoints.
- Backend services are not ready.
- MongoDB or RabbitMQ is not ready.
- Secrets or environment variables are incorrect.

MongoDB auth errors:

```bash
kubectl logs deployment/mongodb -n $NAMESPACE
kubectl logs deployment/auth-service -n $NAMESPACE
```

Likely causes:

- `MONGODB_ROOT_USER`, `MONGODB_ROOT_PASSWORD`, or `MONGODB_DB` mismatch.
- Existing MongoDB PVC was initialized with older credentials.
- `MONGODB_URL` does not include the correct `authSource`.

## 23. Rollback

Rollback deployments:

```bash
kubectl rollout undo deployment/auth-service -n $NAMESPACE
kubectl rollout undo deployment/user-service -n $NAMESPACE
kubectl rollout undo deployment/task-service -n $NAMESPACE
kubectl rollout undo deployment/frontend -n $NAMESPACE
kubectl rollout undo deployment/gateway -n $NAMESPACE
```

Check rollout history:

```bash
kubectl rollout history deployment/auth-service -n $NAMESPACE
```

Best practice:

- Use immutable image tags.
- Keep one manifest set per release.
- Roll forward with a fixed image when possible.

## 24. Cost and Cleanup

Resources that create cost:

- EKS control plane
- EC2 worker nodes
- NAT gateway
- Load balancer
- EBS volumes
- ECR image storage
- Route 53 hosted zone and DNS queries

Delete application:

```bash
kubectl delete namespace $NAMESPACE
```

Delete cluster:

```bash
eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION
```

Delete ECR repositories if no longer needed:

```bash
aws ecr delete-repository --repository-name authdb/auth-service --region $AWS_REGION --force
aws ecr delete-repository --repository-name authdb/user-service --region $AWS_REGION --force
aws ecr delete-repository --repository-name authdb/task-service --region $AWS_REGION --force
aws ecr delete-repository --repository-name authdb/frontend --region $AWS_REGION --force
```

## 25. Production Hardening

Before production launch:

- Replace committed/demo secrets.
- Use AWS Secrets Manager instead of plain YAML secrets.
- Enable TLS.
- Use private subnets for worker nodes.
- Keep MongoDB and RabbitMQ private.
- Consider MongoDB Atlas or Amazon DocumentDB for production database operations.
- Consider Amazon MQ for RabbitMQ or a highly available RabbitMQ operator.
- Enable EKS control plane logging.
- Send application logs to CloudWatch.
- Enable ECR image scanning.
- Use resource requests and limits.
- Add PodDisruptionBudgets.
- Add separate namespaces for staging and production.
- Add CI/CD for build, scan, push, deploy, and rollback.
- Add AWS budgets and billing alerts.

## 26. Official AWS References

- Amazon EKS VPC and subnet considerations: https://docs.aws.amazon.com/eks/latest/best-practices/subnets.html
- Amazon EKS security group requirements: https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html
- Amazon EKS managed node groups: https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html
- Create an Amazon VPC for EKS: https://docs.aws.amazon.com/eks/latest/userguide/creating-a-vpc.html
- AWS Load Balancer Controller on EKS: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
- Install AWS Load Balancer Controller with manifests: https://docs.aws.amazon.com/eks/latest/userguide/lbc-manifest.html

