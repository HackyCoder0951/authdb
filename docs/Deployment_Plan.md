# Kubernetes Deployment Implementation Plan

Date: 21 May 2026

## 1) Objectives
- Deploy all project services to Kubernetes using the existing manifests in k8s/
- Run everything locally using Portainer + minikube
- Use a local container registry or minikube Docker daemon
- Expose the app via Ingress or NodePort
- Ensure health checks, scaling, and basic observability are in place

## 2) Scope
Services in scope:
- auth-service (Python)
- user-service (Python)
- tasks-service (Python)
- frontend (Vite + Nginx)
- gateway (Nginx)
- mongodb (stateful)
- rabbitmq (stateful)

Manifests in scope:
- k8s/namespace.yml
- k8s/secret.yml
- k8s/configmap.yml
- k8s/mongodb-persistent-volume.yml
- k8s/rabbitmq-deployment.yml
- k8s/auth-service-deployment.yml
- k8s/user-service-deployment.yml
- k8s/task-service-deployment.yml
- k8s/gateway-deployment.yml
- k8s/frontend-deployment.yml
- k8s/service.yml
- k8s/ingress.yml
- k8s/hpa.yml

## 3) Preconditions and Decisions (Local + Portainer)
Before deployment, confirm:
- Local cluster: minikube
- Portainer access to the local Kubernetes cluster
- Image source approach:
  - Option A: Local registry (for example, localhost:5000)
  - Option B: minikube Docker daemon (no registry push)
- Ingress or NodePort exposure
- Storage class for MongoDB PVC
- Resource limits/requests for each service

Portainer usage notes:
- Use Portainer to apply YAML (k8s manifests) and monitor workloads
- Ensure Portainer has access to the minikube kubeconfig

## 3.1) Portainer UI Steps (Local)
- Open Portainer and select the local Kubernetes endpoint
- Go to Stacks and create a new stack (type: Kubernetes)
- Paste manifests in the deployment order (or upload files)
- Deploy the stack and confirm all pods become Running
- Use the Portainer dashboard to monitor logs and restart pods if needed

## 4) Image Build and Registry Plan (Local)
### 4.1 Build targets
- services/auth-services/Dockerfile
- services/user-services/Dockerfile
- services/tasks-services/Dockerfile
- frontend/Dockerfile
- gateway/nginx.conf (gateway image expected from project Dockerfile or base image)

### 4.2 Local image naming
Example format (local registry):
- localhost:5000/<project>/auth-service:<tag>
- localhost:5000/<project>/user-service:<tag>
- localhost:5000/<project>/tasks-service:<tag>
- localhost:5000/<project>/frontend:<tag>
- localhost:5000/<project>/gateway:<tag>

Example format (minikube Docker daemon):
- <project>/auth-service:<tag>
- <project>/user-service:<tag>
- <project>/tasks-service:<tag>
- <project>/frontend:<tag>
- <project>/gateway:<tag>

### 4.3 Actions
Option A: Local registry
- Build images locally
- Push to local registry
- Update image references in:
  - k8s/auth-service-deployment.yml
  - k8s/user-service-deployment.yml
  - k8s/task-service-deployment.yml
  - k8s/frontend-deployment.yml
  - k8s/gateway-deployment.yml

Option B: minikube Docker daemon
- Point Docker to minikube and build images locally
- Update image references in:
  - k8s/auth-service-deployment.yml
  - k8s/user-service-deployment.yml
  - k8s/task-service-deployment.yml
  - k8s/frontend-deployment.yml
  - k8s/gateway-deployment.yml

### 4.4 Sample local registry setup (optional)
- Run a local registry container on port 5000
- Configure minikube to trust and pull from localhost:5000
- Tag and push images to localhost:5000/<project>

## 5) Configuration and Secrets
### 5.1 Secrets
Review and populate:
- k8s/secret.yml
- Required fields: DB credentials, JWT secrets, RabbitMQ credentials, and any API keys

### 5.2 ConfigMap
Review and populate:
- k8s/configmap.yml
- Ensure service URLs, ports, and environment flags match the cluster setup

## 6) Persistent Storage
- Validate k8s/mongodb-persistent-volume.yml
- Ensure a compatible StorageClass exists in the cluster
- Confirm PVC size is sufficient for initial load

## 7) Ingress and Networking (Local)
Choose one:
- Ingress: install nginx-ingress in minikube and use k8s/ingress.yml
- NodePort: skip Ingress and expose gateway/frontend services directly

If using Ingress:
- Update k8s/ingress.yml with a local host (for example, authdb.local)
- Add a hosts entry on the local machine for the Ingress IP

If using NodePort:
- Update k8s/service.yml to NodePort for gateway/frontend
- Access services via minikube IP and NodePort

## 8) Deployment Order
Apply manifests in this order:
1. k8s/namespace.yml
2. k8s/secret.yml
3. k8s/configmap.yml
4. k8s/mongodb-persistent-volume.yml
5. k8s/rabbitmq-deployment.yml
6. k8s/auth-service-deployment.yml
7. k8s/user-service-deployment.yml
8. k8s/task-service-deployment.yml
9. k8s/gateway-deployment.yml
10. k8s/frontend-deployment.yml
11. k8s/service.yml
12. k8s/ingress.yml
13. k8s/hpa.yml

## 9) Health and Readiness
- Confirm each service exposes a health endpoint (already defined in service routes)
- Validate readiness and liveness probes in deployments
- Verify the frontend ServiceHealth view reads from gateway endpoints

## 10) Autoscaling
- Ensure metrics-server is installed
- Confirm HPA targets match CPU requests in each deployment
- Update k8s/hpa.yml thresholds based on expected load

## 11) Smoke Tests
- Verify ingress URL resolves
- Register/login a user and reach dashboard
- Check Admin Panel access
- Verify tasks CRUD via gateway
- Confirm health endpoints return success

## 12) Rollback Plan
- Use kubectl rollout undo for failed deployments
- Maintain versioned image tags for quick rollback
- Keep a known-good manifest set

## 13) CI/CD Recommendations (Optional)
- Add a pipeline to build and push images
- Apply manifests after successful build
- Separate environments (dev/stage/prod) via namespaces and config overlays

## 14) Risks and Mitigations
- Risk: misconfigured secrets -> Mitigation: validate secret.yml before apply
- Risk: PVC unavailable -> Mitigation: verify StorageClass and PV binding
- Risk: Ingress misrouting -> Mitigation: test gateway routes directly via port-forward
- Risk: resource limits too low -> Mitigation: adjust requests/limits and HPA

## 15) Validation Checklist
- All pods in Running state
- Services have endpoints
- Ingress routes to gateway and frontend
- Auth flow works end-to-end
- Task and user services reachable from gateway
- MongoDB and RabbitMQ healthy

## 16) Local Minikube Step-by-Step (Commands)
### STEP 2 — Enable Required Addons
Enable ingress and metrics-server:
```bash
minikube addons enable ingress
minikube addons enable metrics-server
```

### STEP 3 — Use Minikube Docker Environment
Point Docker to the minikube daemon so images are available without a registry:
```bash
eval $(minikube docker-env)
```

### STEP 4 — Build All Images
Run from the repo root:
```bash
docker build -t authdb/auth-service:v1 ./services/auth-services
docker build -t authdb/user-service:v1 ./services/user-services
docker build -t authdb/tasks-service:v1 ./services/tasks-services
docker build -t authdb/frontend:v1 ./frontend
docker build -t authdb/gateway:v1 ./gateway
```

### STEP 5 — Update Deployment YAML Files
Update image names to match the tags built in STEP 4:
- k8s/auth-service-deployment.yml -> authdb/auth-service:v1
- k8s/user-service-deployment.yml -> authdb/user-service:v1
- k8s/task-service-deployment.yml -> authdb/tasks-service:v1
- k8s/frontend-deployment.yml -> authdb/frontend:v1
- k8s/gateway-deployment.yml -> authdb/gateway:v1

### STEP 6 — Deploy Kubernetes Resources
Apply manifests in order:
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
kubectl apply -f k8s/ingress.yml
kubectl apply -f k8s/hpa.yml
```
