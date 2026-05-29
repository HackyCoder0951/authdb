# AuthDB — Comprehensive Architecture & Scalability

This document consolidates the project architecture, Kubernetes deployment, API & microservices scalability patterns, and an AWS production topology. Diagrams are provided in Mermaid so you can paste them into docs or slide decks.

---

## 1 — System Overview (High level)

```mermaid
graph TB

    User["User Browser"]

    subgraph Frontend
        React["React SPA"]
        Nginx["Nginx Web Server"]
    end

    User --> React
    React --> Nginx

    subgraph Gateway
        Ingress["Kubernetes Ingress / Nginx Gateway"]
    end

    Nginx --> Ingress

    subgraph Microservices
        Auth["Auth Service<br/>FastAPI :8001"]
        Users["User Service<br/>FastAPI :8002"]
        Tasks["Task Service<br/>FastAPI :8003"]
    end

    Ingress --> Auth
    Ingress --> Users
    Ingress --> Tasks

    Mongo[(MongoDB Replica Set)]
    Rabbit[(RabbitMQ)]

    Auth --> Mongo
    Users --> Mongo
    Tasks --> Mongo

    Auth --> Rabbit
    Users --> Rabbit
    Tasks --> Rabbit

    subgraph Monitoring
        Prom["Prometheus"]
        Graf["Grafana"]
        Logs["Fluentd / Loki"]
    end

    Auth -. Metrics .-> Prom
    Users -. Metrics .-> Prom
    Tasks -. Metrics .-> Prom

    Prom --> Graf

    Auth -. Logs .-> Logs
    Users -. Logs .-> Logs
    Tasks -. Logs .-> Logs
```

Brief: the SPA serves static assets, proxies API calls to the gateway which routes to one of three FastAPI services. Stateful components (MongoDB and RabbitMQ) are internal cluster-services.

---

## 2 — Kubernetes Architecture (cluster view)

```mermaid
flowchart TB

    User["User Browser"]

    Ingress["Nginx Ingress Controller"]

    User -->|HTTPS| Ingress

    subgraph "authdb Namespace"

        FrontendSvc["Frontend Service"]
        GatewaySvc["Gateway Service"]

        Ingress --> FrontendSvc
        Ingress --> GatewaySvc

        FrontendSvc --> FrontendPods["Frontend Deployment<br/>3 Replicas"]

        GatewaySvc --> GatewayPods["Gateway Deployment<br/>3 Replicas"]

        GatewayPods --> AuthSvc["Auth Service"]
        GatewayPods --> UserSvc["User Service"]
        GatewayPods --> TaskSvc["Task Service"]

        AuthSvc --> AuthPods["Auth Deployment"]
        UserSvc --> UserPods["User Deployment"]
        TaskSvc --> TaskPods["Task Deployment"]

        AuthPods --> MongoSvc["MongoDB Service"]
        UserPods --> MongoSvc
        TaskPods --> MongoSvc

        AuthPods --> RabbitSvc["RabbitMQ Service"]
        UserPods --> RabbitSvc
        TaskPods --> RabbitSvc

        MongoSvc --> Mongo["MongoDB StatefulSet<br/>PVC Storage"]
        RabbitSvc --> Rabbit["RabbitMQ Deployment"]
    end

    subgraph Observability
        Prom["Prometheus"]
        Graf["Grafana"]
        Logs["Loki / Fluentd"]
    end

    AuthPods -. Metrics .-> Prom
    UserPods -. Metrics .-> Prom
    TaskPods -. Metrics .-> Prom

    Prom --> Graf

    AuthPods -. Logs .-> Logs
    UserPods -. Logs .-> Logs
    TaskPods -. Logs .-> Logs
```

Key points:
- Use `ClusterIP` for internal services, `LoadBalancer`/Ingress for external access.
- Keep MongoDB and RabbitMQ in private subnets/ClusterIP; do not expose them publicly.
- Use PVC for MongoDB persistence.

---

## 3 — API Scalability Patterns

1. Horizontal Pod Autoscaling

```mermaid
flowchart LR

    Users["Users"]
    Ingress["Nginx Ingress"]

    Users --> Ingress

    Ingress --> Pod1["auth-service Pod"]
    Ingress --> Pod2["auth-service Pod"]
    Ingress --> Pod3["auth-service Pod"]

    Metrics["Metrics Server"]

    Metrics --> HPA["Horizontal Pod Autoscaler"]

    HPA -. Increase Replicas .-> Pod1
    HPA -. Increase Replicas .-> Pod2
    HPA -. Increase Replicas .-> Pod3

    HPA -. Create New Pods .-> NewPods["Additional Pods"]

    NewPods --> Ingress
    NewPods --> Pod1
    NewPods --> Pod2
    NewPods --> Pod3
```

- Set CPU/memory requests & limits to enable HPA decisions.
- Use readiness probes so traffic is not sent to warming pods.

2. Caching + Read Optimization

```mermaid
sequenceDiagram
    participant Client
    participant Gateway
    participant AuthService
    participant TaskService
    participant Redis
    participant MongoDB

    Client->>Gateway: GET /api/v1/tasks (JWT)

    Gateway->>AuthService: Validate Token
    AuthService-->>Gateway: Valid User

    Gateway->>TaskService: Get Tasks

    TaskService->>Redis: GET tasks:user:123

    alt Cache Hit
        Redis-->>TaskService: Cached Tasks
    else Cache Miss
        Redis-->>TaskService: MISS
        TaskService->>MongoDB: Query Tasks
        MongoDB-->>TaskService: Results
        TaskService->>Redis: SET Cache
    end

    TaskService-->>Gateway: Tasks
    Gateway-->>Client: 200 OK
```

- Use Redis (or ElastiCache on AWS) for frequent reads (task lists, user sessions). Evict/invalidate on writes.

3. Database Scaling
- Vertical scale for primary Mongo instance and use replica sets for read scaling and HA.
- On AWS use Amazon DocumentDB or a managed MongoDB Atlas cluster for production; configure replica sets and backups.

4. Message Broker and Asynchronous Work
- Offload long-running or cross-service lookups (RPC) via RabbitMQ. Use durable queues and appropriate prefetch counts.
- For very high fanout use topics/exchanges or switch to Kafka if ordering/throughput demands grow.

---

## 4 — Microservices Scalability & Resilience Patterns

- Circuit Breakers / Retry policies: implement with client libraries (HTTPX, Tenacity). Keep idempotency keys for POSTs.
- Bulkheads: limit concurrency per downstream dependency (DB / external APIs) to avoid cascading failures.
- Health checks: liveness + readiness endpoints used by K8s to manage rolling updates.
- Observability: Prometheus metrics + Grafana dashboards, structured logs shipped to ELK/CloudWatch.

```mermaid
graph TB

    Client["Client"]

    Gateway["API Gateway"]

    Auth["Auth Service"]
    User["User Service"]
    Task["Task Service"]

    Mongo[("MongoDB")]
    Redis[("Redis Cache")]
    Rabbit[("RabbitMQ")]

    Client --> Gateway

    Gateway --> Auth
    Gateway --> User
    Gateway --> Task

    Auth --> Mongo
    User --> Mongo
    Task --> Mongo

    Auth --> Redis
    User --> Redis
    Task --> Redis

    Auth --> Rabbit
    User --> Rabbit
    Task --> Rabbit

    subgraph ResilienceLayer["Resilience Layer"]
        CB["Circuit Breaker"]
        RT["Retry Policy"]
        BH["Bulkhead"]
        RL["Rate Limiter"]
        TO["Timeout Policy"]
    end

    Mongo -. Circuit Breaker .-> CB
    Rabbit -. Retry .-> RT
    Redis -. Bulkhead .-> BH

    Gateway -. Rate Limit .-> RL
    Gateway -. Request Timeout .-> TO
```

---

## 5 — AWS Production Topology (EKS + ECR + Managed Services)

```mermaid
flowchart TB

    Internet["Internet"]

    ALB["ALB / NLB + TLS"]
    Ingress["AWS Load Balancer Controller"]

    FrontendSvc["Frontend Service"]
    GatewaySvc["Gateway Service"]

    Internet --> ALB
    ALB --> Ingress

    Ingress --> FrontendSvc
    Ingress --> GatewaySvc

    subgraph EKS["Amazon EKS Cluster"]

        AuthSvc["Auth Service"]
        UserSvc["User Service"]
        TaskSvc["Task Service"]

        MongoDB["MongoDB Atlas<br/>or Self-Managed MongoDB"]

        RabbitMQ["Amazon MQ<br/>or Self-Managed RabbitMQ"]

        GatewaySvc --> AuthSvc
        GatewaySvc --> UserSvc
        GatewaySvc --> TaskSvc

        AuthSvc --> MongoDB
        UserSvc --> MongoDB
        TaskSvc --> MongoDB

        AuthSvc --> RabbitMQ
        UserSvc --> RabbitMQ
        TaskSvc --> RabbitMQ
    end

    subgraph AWSInfra["AWS Infrastructure"]

        ECR["Amazon ECR"]
        S3["Amazon S3"]
        CloudWatch["Amazon CloudWatch"]
        DevOps["DevOps Team"]

        ECR -->|Pull Images| EKS
        S3 -->|Backups| MongoDB
        CloudWatch -->|Logs & Metrics| DevOps
    end
```

Recommendations for AWS:
- Use ECR for images and deploy via CI/CD (GitHub Actions or CodeBuild -> kubectl apply / Helm).
- Use EKS with managed nodegroups or Fargate for smaller services.
- Use Elastic File System or EBS for persistent storage for Mongo if self-managing.
- Consider fully managed alternatives for production: MongoDB Atlas, Amazon MQ (RabbitMQ), and Amazon ElastiCache (Redis) to minimize operational overhead.

---

## 6 — CI/CD, Release & Rollback

- Build images in CI, tag with semver/sha, push to ECR.
- Use `kubectl` or `helm` for declarative deploys; keep manifests versioned and templatized.
- Use `kubectl rollout undo` for quick rollbacks; use readiness probes to prevent bad releases.

---

## 7 — Quick Troubleshooting Checklist

- `kubectl get pods -n authdb` — check pod states
- `kubectl logs -n authdb deployment/auth-service` — service logs
- `kubectl port-forward svc/gateway 8080:80 -n authdb` — debug API routing
- Check `rabbitmq` and `mongodb` pod logs for connectivity issues

---

## Files in repo referenced
- `k8s/*.yml`, `services/*/Dockerfile`, `frontend/Dockerfile`, `gateway/nginx.conf`, `docker-compose.yml`

---

AuthDB — architecture summary generated from repository docs and manifests. Use sections or diagrams in presentations as-is (Mermaid native).
