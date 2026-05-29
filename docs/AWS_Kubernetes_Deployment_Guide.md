# AWS Kubernetes Deployment Guide

Date: 28 May 2026

This guide deploys the complete AuthDB project to an AWS Kubernetes stack using Amazon EKS, Amazon ECR, Kubernetes manifests, MongoDB, RabbitMQ, the FastAPI services, the Nginx gateway, and the React frontend.

The project already contains Kubernetes manifests in `k8s/`. This guide explains how to prepare AWS, build and push images, update the manifests, deploy the cluster resources, expose the app, and verify the deployment.

## 1. Target Architecture

Production-style AWS stack:

- Amazon EKS for Kubernetes workloads
- Amazon ECR for private container images
- AWS-managed worker nodes or Fargate profiles
- Amazon EBS-backed PersistentVolumeClaim for MongoDB data
- AWS Load Balancer or Nginx Ingress Controller for public access
- Kubernetes Secrets and ConfigMaps for application configuration
- HorizontalPodAutoscaler for frontend, auth, user, and task services

Project workloads:

- `frontend`: React/Vite app served by Nginx on port `80`
- `gateway`: Nginx API gateway on port `80`
- `auth-service`: FastAPI service on port `8001`
- `user-service`: FastAPI service on port `8002`
- `task-service`: FastAPI service on port `8003`
- `mongodb`: MongoDB on port `27017`
- `rabbitmq`: RabbitMQ on ports `5672` and `15672`

Namespace:

```bash
authdb
```

## 2. Repository Files Used

Kubernetes files:

```text
k8s/namespace.yml
k8s/secret.yml
k8s/configmap.yml
k8s/mongodb-persistent-volume.yml
k8s/rabbitmq-deployment.yml
k8s/auth-service-deployment.yml
k8s/user-service-deployment.yml
k8s/task-service-deployment.yml
k8s/gateway-deployment.yml
k8s/frontend-deployment.yml
k8s/service.yml
k8s/ingress.yml
k8s/hpa.yml
```

Dockerfiles:

```text
services/auth-services/Dockerfile
services/user-services/Dockerfile
services/tasks-services/Dockerfile
frontend/Dockerfile
```

The gateway currently uses the public `nginx:1.27-alpine` image and loads its Nginx config from the `gateway-nginx-config` ConfigMap in `k8s/configmap.yml`, so a custom gateway image is not required.

## 3. Prerequisites

Install and configure:

- AWS CLI authenticated to the target AWS account
- Docker
- kubectl
- eksctl
- Helm, if using an ingress controller or AWS Load Balancer Controller
- An AWS IAM user or role with permissions for EKS, ECR, EC2, IAM, CloudFormation, and Elastic Load Balancing

Set deployment variables:

```bash
export AWS_REGION=us-east-1
export CLUSTER_NAME=authdb-prod
export NAMESPACE=authdb
export IMAGE_TAG=v1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
```

Use your preferred AWS region. Keep the same region for EKS, ECR, EBS volumes, and load balancers.

## 4. Security Preparation

Before deploying, replace all demo secrets in `k8s/secret.yml`.

Required secret keys:

```text
SECRET_KEY
RABBITMQ_DEFAULT_USER
RABBITMQ_DEFAULT_PASS
MONGODB_ROOT_USER
MONGODB_ROOT_PASSWORD
MONGODB_DB
```

Generate a strong JWT secret:

```bash
openssl rand -hex 32
```

Important production notes:

- Do not commit real production secrets to Git.
- Prefer AWS Secrets Manager plus External Secrets Operator for production.
- Rotate any credentials that were ever committed, shared, or used in a public environment.
- Use separate secrets per environment: dev, staging, and production.
- Do not use `guest/guest` RabbitMQ credentials outside local development.

## 5. Create ECR Repositories

Create one repository per custom application image:

```bash
aws ecr create-repository --repository-name authdb/auth-service --region $AWS_REGION
aws ecr create-repository --repository-name authdb/user-service --region $AWS_REGION
aws ecr create-repository --repository-name authdb/task-service --region $AWS_REGION
aws ecr create-repository --repository-name authdb/frontend --region $AWS_REGION
```

Log Docker in to ECR:

```bash
aws ecr get-login-password --region $AWS_REGION \
  | docker login --username AWS --password-stdin $ECR_REGISTRY
```

## 6. Build and Push Images

Run these commands from the repository root.

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

Push images:

```bash
docker push $ECR_REGISTRY/authdb/auth-service:$IMAGE_TAG
docker push $ECR_REGISTRY/authdb/user-service:$IMAGE_TAG
docker push $ECR_REGISTRY/authdb/task-service:$IMAGE_TAG
docker push $ECR_REGISTRY/authdb/frontend:$IMAGE_TAG
```

Use immutable tags for real releases, for example:

```text
git-sha-20260528
release-1.0.0
```

Avoid `latest` in staging and production.

## 7. Create the EKS Cluster

Simple managed-node cluster:

```bash
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --managed \
  --nodes 3 \
  --node-type t3.medium
```

Update kubeconfig:

```bash
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
kubectl get nodes
```

For production, create the cluster through Terraform, CloudFormation, or an `eksctl` config file so networking, private subnets, logging, node groups, and add-ons are repeatable.

## 8. Enable Storage for MongoDB

`k8s/mongodb-persistent-volume.yml` creates a `PersistentVolumeClaim` named `mongodb-data`. On EKS, dynamic EBS provisioning requires the AWS EBS CSI driver.

Install or enable the AWS EBS CSI driver as an EKS add-on before deploying MongoDB:

```bash
aws eks describe-addon --cluster-name $CLUSTER_NAME --addon-name aws-ebs-csi-driver --region $AWS_REGION
```

If the add-on is not installed, enable it from the EKS console or with your infrastructure tool. After installation, confirm the cluster has a default `StorageClass`:

```bash
kubectl get storageclass
```

For production data, consider MongoDB Atlas or Amazon DocumentDB instead of running single-replica MongoDB inside the cluster.

## 9. Update Kubernetes Image References

Edit these deployment files and replace local image names with ECR image URIs:

```text
k8s/auth-service-deployment.yml
k8s/user-service-deployment.yml
k8s/task-service-deployment.yml
k8s/frontend-deployment.yml
```

Expected values:

```yaml
image: <account-id>.dkr.ecr.<region>.amazonaws.com/authdb/auth-service:v1
image: <account-id>.dkr.ecr.<region>.amazonaws.com/authdb/user-service:v1
image: <account-id>.dkr.ecr.<region>.amazonaws.com/authdb/task-service:v1
image: <account-id>.dkr.ecr.<region>.amazonaws.com/authdb/frontend:v1
```

Keep this setting:

```yaml
imagePullPolicy: IfNotPresent
```

For immutable release tags, `IfNotPresent` is fine. If you reuse tags during development, use `Always` or delete pods after pushing a new image.

## 10. Review Runtime Configuration

`k8s/configmap.yml` contains:

```text
DB_NAME
MONGODB_URL
USER_RPC_QUEUE
ALGORITHM
ACCESS_TOKEN_EXPIRE_MINUTES
gateway-nginx-config
```

The service deployments override `MONGODB_URL` with this in-cluster authenticated connection string:

```text
mongodb://$(MONGODB_USER):$(MONGODB_PASSWORD)@mongodb:27017/$(MONGODB_DB)?authSource=admin
```

That means the application services connect to the Kubernetes `mongodb` Service, not to the Atlas URL from local `.env`.

The frontend defaults API requests to:

```text
/api/v1
```

The frontend Nginx config proxies `/api/` to the internal Kubernetes service:

```text
http://gateway/api/
```

So the recommended public entrypoint is the frontend. Browser requests go to the frontend, and API traffic is proxied internally to the gateway.

## 11. Deploy Kubernetes Resources

Apply manifests in this order:

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

Wait for rollout:

```bash
kubectl rollout status deployment/mongodb -n $NAMESPACE
kubectl rollout status deployment/rabbitmq -n $NAMESPACE
kubectl rollout status deployment/auth-service -n $NAMESPACE
kubectl rollout status deployment/user-service -n $NAMESPACE
kubectl rollout status deployment/task-service -n $NAMESPACE
kubectl rollout status deployment/gateway -n $NAMESPACE
kubectl rollout status deployment/frontend -n $NAMESPACE
```

Check pods and services:

```bash
kubectl get pods -n $NAMESPACE
kubectl get svc -n $NAMESPACE
kubectl get pvc -n $NAMESPACE
```

## 12. Public Access Options

Choose one option.

### Option A: Simple LoadBalancer for the Frontend

This is the quickest complete deployment path.

Patch the frontend service to create an AWS load balancer:

```bash
kubectl patch svc frontend -n $NAMESPACE -p '{"spec":{"type":"LoadBalancer"}}'
```

Wait for the external address:

```bash
kubectl get svc frontend -n $NAMESPACE --watch
```

Open the `EXTERNAL-IP` or hostname shown for the frontend service.

Recommended adjustment: make the gateway service private if users should only access APIs through the frontend:

```bash
kubectl patch svc gateway -n $NAMESPACE -p '{"spec":{"type":"ClusterIP"}}'
```

### Option B: Ingress Controller

Use this option when you want hostnames, TLS, and cleaner routing.

Install an ingress controller in EKS. You can use either:

- Nginx Ingress Controller with an AWS load balancer in front of it
- AWS Load Balancer Controller with an ALB

The existing `k8s/ingress.yml` expects:

```yaml
ingressClassName: nginx
```

So if you use the existing file unchanged, install Nginx Ingress Controller first. Then apply:

```bash
kubectl apply -f k8s/ingress.yml
kubectl get ingress -n $NAMESPACE
```

The existing ingress routes `/` to the `frontend` Service. API calls still work because the frontend Nginx config proxies `/api/` to the internal `gateway` Service.

For a real domain:

1. Create or use a Route 53 hosted zone.
2. Point an `A` or `CNAME` record to the ingress/load balancer hostname.
3. Add TLS with AWS Certificate Manager or cert-manager.
4. Add a `host` field to `k8s/ingress.yml`.

Example host rule:

```yaml
rules:
  - host: authdb.example.com
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: frontend
              port:
                number: 80
```

## 13. Verify the Deployment

Health checks:

```bash
kubectl get pods -n $NAMESPACE
kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/name=auth-service
kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/name=user-service
kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/name=task-service
```

Port-forward the frontend for a private smoke test:

```bash
kubectl port-forward svc/frontend 8080:80 -n $NAMESPACE
```

Open:

```text
http://localhost:8080
```

Port-forward the gateway API:

```bash
kubectl port-forward svc/gateway 8081:80 -n $NAMESPACE
```

Test gateway health:

```bash
curl http://localhost:8081/api/v1/health
curl http://localhost:8081/api/v1/health/auth
curl http://localhost:8081/api/v1/health/users
curl http://localhost:8081/api/v1/health/tasks
```

Application smoke test:

1. Open the frontend URL.
2. Register a user.
3. Log in.
4. Create a task.
5. Edit and delete a task according to the role rules.
6. Confirm the service health panel shows healthy services.

## 14. Troubleshooting

Image pull errors:

```bash
kubectl describe pod <pod-name> -n $NAMESPACE
kubectl get events -n $NAMESPACE --sort-by=.lastTimestamp
```

Fixes:

- Confirm image names use the correct account ID, region, repository, and tag.
- Confirm the worker nodes can pull from ECR.
- Confirm ECR repositories exist in the same region.

MongoDB pod pending:

```bash
kubectl describe pvc mongodb-data -n $NAMESPACE
kubectl get storageclass
```

Fixes:

- Enable the AWS EBS CSI driver.
- Confirm a default StorageClass exists.
- Confirm the node group has capacity in the same Availability Zone as the EBS volume.

Readiness probe failures:

```bash
kubectl logs deployment/auth-service -n $NAMESPACE
kubectl logs deployment/user-service -n $NAMESPACE
kubectl logs deployment/task-service -n $NAMESPACE
kubectl logs deployment/gateway -n $NAMESPACE
```

Fixes:

- Confirm MongoDB and RabbitMQ pods are ready.
- Confirm `SECRET_KEY`, MongoDB credentials, and RabbitMQ credentials are set.
- Confirm service DNS names are correct: `mongodb`, `rabbitmq`, `auth-service`, `user-service`, `task-service`, `gateway`.

Frontend opens but API fails:

```bash
kubectl logs deployment/frontend -n $NAMESPACE
kubectl logs deployment/gateway -n $NAMESPACE
kubectl get endpoints -n $NAMESPACE
```

Fixes:

- Confirm the `gateway` Service exists and has endpoints.
- Confirm `frontend/nginx.conf` proxies `/api/` to `http://gateway/api/`.
- Confirm gateway routes are loaded from `gateway-nginx-config`.

HPA does not show metrics:

```bash
kubectl top pods -n $NAMESPACE
kubectl get hpa -n $NAMESPACE
```

Fixes:

- Install metrics-server or the EKS metrics add-on.
- Confirm CPU requests exist on deployments.

## 15. Rollback

Rollback a failed deployment:

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

Rollback strategy:

- Keep immutable image tags.
- Deploy one release tag at a time.
- Do not overwrite a tag after it has been deployed to production.
- Keep a copy of the exact manifests used for each release.

## 16. Production Hardening Checklist

- Replace demo secrets with secure production values.
- Use AWS Secrets Manager or External Secrets Operator.
- Enable TLS on the public entrypoint.
- Add Route 53 DNS records.
- Restrict public exposure to only the frontend or ingress controller.
- Keep MongoDB and RabbitMQ private.
- Use managed MongoDB Atlas or Amazon DocumentDB for production-grade database operations.
- Use Amazon MQ for RabbitMQ or a RabbitMQ operator if high availability is required.
- Add PodDisruptionBudgets for stateless services.
- Add NetworkPolicies if your EKS networking plugin supports them.
- Send application and Nginx logs to CloudWatch.
- Enable EKS control plane logging.
- Use separate namespaces or clusters for dev, staging, and production.
- Add CI/CD to build, scan, push, and deploy images.
- Scan images for vulnerabilities in ECR.
- Use Kubernetes resource requests and limits for every container.
- Use immutable image tags instead of `latest`.

## 17. Cleanup

Delete app resources:

```bash
kubectl delete namespace $NAMESPACE
```

Delete the EKS cluster:

```bash
eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION
```

Delete ECR repositories only when images are no longer needed:

```bash
aws ecr delete-repository --repository-name authdb/auth-service --region $AWS_REGION --force
aws ecr delete-repository --repository-name authdb/user-service --region $AWS_REGION --force
aws ecr delete-repository --repository-name authdb/task-service --region $AWS_REGION --force
aws ecr delete-repository --repository-name authdb/frontend --region $AWS_REGION --force
```

