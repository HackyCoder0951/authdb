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
