# System Architecture

## Overview
AuthDB is a full-stack application built around a React frontend, an Nginx gateway, and three FastAPI services deployed on AWS EKS. Terraform owns the AWS foundation, the ECR repositories, and the Kubernetes workloads, so the architecture diagram and the infrastructure stay aligned.

## Application Topology

```mermaid
graph TD
    Browser[Browser] --> Frontend[Frontend SPA - Vite + React]
    Frontend --> Gateway[Nginx Gateway]

    Gateway --> AuthSvc[auth-service]
    Gateway --> UserSvc[user-service]
    Gateway --> TaskSvc[task-service]

    AuthSvc --> Mongo[(MongoDB)]
    UserSvc --> Mongo
    TaskSvc --> Mongo

    AuthSvc --> MQ[(RabbitMQ)]
    UserSvc --> MQ
    TaskSvc --> MQ
```

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
        VPC[VPC]
        IGW[Internet Gateway]
        RT[Public Route Table]
        Subnets[2 Public Subnets]
        EKS[EKS Cluster]
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

## Frontend Architecture
- React + TypeScript SPA with routes for login, register, dashboard, and admin panel.
- Auth state is managed by `AuthContext`, which decodes JWTs and hydrates user permissions from `/users/:id`.
- Permission gates hide UI actions when the user lacks `read:tasks`, `write:tasks`, `delete:tasks`, or `manage:users`.
- The API client sends `Authorization: Bearer <token>` to the gateway at `/api/v1`.

## Gateway Responsibilities
- Routes `/api/v1/auth/*` to `auth-service`.
- Routes `/api/v1/users/*` to `user-service`.
- Routes `/api/v1/tasks/*` to `task-service`.
- Exposes health endpoints for each service via `/api/v1/health/*`.

## Backend Services

### auth-service
- Handles registration and login.
- Issues JWT access tokens.
- Publishes auth events to RabbitMQ.

### user-service
- Admin-only CRUD for users.
- Stores roles and permissions.
- Hosts an RPC server for user lookups.

### task-service
- CRUD for tasks.
- Enforces ownership and permission checks (`read:tasks`, `write:tasks`, `delete:tasks`).
- Requires valid JWTs for all task operations.

## Terraform Layer Map

| Layer | Terraform files | Purpose |
| --- | --- | --- |
| Network | `networking.tf`, `variables.tf` | VPC, public subnets, internet gateway, public route table, CIDR controls |
| Identity and compute | `iam.tf`, `eks.tf` | IAM roles, EKS cluster, managed node group, EKS add-ons |
| Container registry | `ecr.tf`, `outputs.tf` | ECR repositories and output values for image publishing |
| Kubernetes base | `kubernetes.tf` | Namespace, Secret, ConfigMap, PVC, and shared Kubernetes resources |
| Kubernetes workloads | `kubernetes-apps.tf`, `kubernetes-services.tf` | Deployments, Services, and optional HPA |
| Documentation outputs | `outputs.tf` | Values used by docs, scripts, and deployment helpers |

## Authentication and Permissions Flow

```mermaid
sequenceDiagram
    participant U as User
    participant FE as Frontend
    participant G as Gateway
    participant A as Auth Service
    participant US as User Service

    U->>FE: Login
    FE->>G: POST /api/v1/auth/login
    G->>A: login
    A-->>FE: access_token
    FE->>G: GET /api/v1/users/:id
    G->>US: fetch profile
    US-->>FE: role + permissions
```

## Terraform to Mermaid Workflow
1. Apply the AWS foundation and ECR repositories with `terraform apply` in `terraform/aws-eks`.
2. Build and push the application images with the generated ECR repository URLs.
3. Enable `deploy_kubernetes = true` and apply again to create the Kubernetes workloads.
4. Regenerate the architecture summary with `bash scripts/terraform-to-mermaid.sh > docs/aws-architecture.generated.md` when the Terraform outputs change.

## Data Model Summary
- Users: email, role, permissions, created_at.
- Tasks: title, description, owner_id, created_at.

## Related Docs
- Frontend details: docs/Front-End.md
- Backend details: docs/Back-End.md
- Database schema: docs/DB_Schema.md
- CloudFormation template: cloudformation/authdb-eks-architecture.yaml
# System Architecture

## Overview
This document summarizes the end-to-end architecture for AuthDB, covering the frontend SPA, the Nginx gateway, and the FastAPI microservices.

## High-Level Topology

```mermaid
graph TD
    Browser[Browser] --> Frontend[Frontend - Vite + React]
    Frontend --> Gateway[Nginx Gateway]

    Gateway --> AuthSvc[auth-service]
    Gateway --> UserSvc[user-service]
    Gateway --> TaskSvc[task-service]

    AuthSvc --> Mongo[(MongoDB)]
    UserSvc --> Mongo
    TaskSvc --> Mongo

    AuthSvc --> MQ[(RabbitMQ)]
    UserSvc --> MQ
    TaskSvc --> MQ
```


## Frontend Architecture
- React + TypeScript SPA with routes for login, register, dashboard, and admin panel.
- Auth state is managed by `AuthContext`, which decodes JWTs and hydrates user permissions from `/users/:id`.
- Permission gates hide UI actions when the user lacks `read:tasks`, `write:tasks`, `delete:tasks`, or `manage:users`.
- The API client sends `Authorization: Bearer <token>` to the gateway at `/api/v1`.

## Gateway Responsibilities
- Routes `/api/v1/auth/*` to `auth-service`.
- Routes `/api/v1/users/*` to `user-service`.
- Routes `/api/v1/tasks/*` to `task-service`.
- Exposes health endpoints for each service via `/api/v1/health/*`.

## Backend Services

### auth-service
- Handles registration and login.
- Issues JWT access tokens.
- Publishes auth events to RabbitMQ.

### user-service
- Admin-only CRUD for users.
- Stores roles and permissions.
- Hosts an RPC server for user lookups.

### task-service
- CRUD for tasks.
- Enforces ownership and permission checks (`read:tasks`, `write:tasks`, `delete:tasks`).
- Requires valid JWTs for all task operations.

## Authentication and Permissions Flow

```mermaid
sequenceDiagram
    participant U as User
    participant FE as Frontend
    participant G as Gateway
    participant A as Auth Service
    participant US as User Service

    U->>FE: Login
    FE->>G: POST /api/v1/auth/login
    G->>A: login
    A-->>FE: access_token
    FE->>G: GET /api/v1/users/:id
    G->>US: fetch profile
    US-->>FE: role + permissions
```

## Data Model Summary
- Users: email, role, permissions, created_at.
- Tasks: title, description, owner_id, created_at.

## Related Docs
- Frontend details: docs/Front-End.md
- Backend details: docs/Back-End.md
- Database schema: docs/DB_Schema.md
