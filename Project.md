# Project Analysis

## Overview

This project is a full-stack authentication and task management system built with:

- `FastAPI` for the backend REST API
- `MongoDB` with `motor` for async database access
- `React + TypeScript + Vite` for the frontend
- `JWT` for authentication
- Role-based authorization for user and admin actions
- `Docker` and `docker-compose` for containerized startup
- `GitHub Actions` for CI

The codebase is organized as two main applications:

- `backend/`: API, auth, database access, schemas, and route handlers
- `frontend/`: login/register UI, dashboard, admin panel, shared state, and API client logic

---

## Core Features

### Authentication

- User registration with email, password, and optional name
- Password hashing using `bcrypt`
- User login using OAuth2 password form flow
- JWT access token generation
- Token-based session persistence in frontend `localStorage`
- Automatic token decoding on frontend app startup
- Auto logout when token is expired or invalid

### Authorization

- Role-based access control with `USER` and `ADMIN`
- Protected frontend routes using a private route wrapper
- Backend dependency-based authorization guards
- Admin-only access for user management and viewing all tasks
- Ownership-based control for task updates and deletes

### Task Management

- Create tasks
- List current user's tasks
- Update owned tasks
- Delete owned tasks
- Admin ability to delete any task
- Admin endpoint to fetch all tasks

### User Management

- Public self-registration flow
- Admin-created user accounts
- Admin list of all users
- Admin update of user role, name, and permissions
- Admin delete user accounts
- User or admin can fetch a specific user record

### Frontend Experience

- Login page
- Registration page
- Protected dashboard
- Admin panel for user management
- Toast notification system for success/error/info messages
- Global Axios response interceptor for centralized API error handling
- API health/status indicator on dashboard and admin panel

### Platform and DevOps

- Dockerfiles for backend and frontend
- `docker-compose.yml` to run both services together
- CI workflow for backend verification and frontend build
- Backend startup/shutdown database lifecycle hooks
- Custom colored logger for console output

---

## Project Structure

```text
authdb/
├── .github/
│   └── workflows/
│       └── ci.yml
├── backend/
│   ├── app/
│   │   ├── core/
│   │   │   ├── config.py
│   │   │   ├── dependencies.py
│   │   │   └── security.py
│   │   ├── db/
│   │   │   └── mongodb.py
│   │   ├── models/
│   │   │   ├── task.py
│   │   │   └── user.py
│   │   ├── routes/
│   │   │   └── api/
│   │   │       ├── v1/
│   │   │       │   ├── auth.py
│   │   │       │   ├── health.py
│   │   │       │   ├── tasks.py
│   │   │       │   └── users.py
│   │   │       └── v2/
│   │   │           └── verify_db.py
│   │   ├── schemas/
│   │   │   ├── task.py
│   │   │   └── user.py
│   │   ├── utils/
│   │   │   └── logger.py
│   │   └── main.py
│   ├── Dockerfile
│   └── requirements.txt
├── docs/
│   ├── Back-End.md
│   ├── DB_Schema.md
│   ├── Front-End.md
│   ├── Scalability_Guide.md
│   └── Screenshot of working/
├── frontend/
│   ├── public/
│   │   └── vite.svg
│   ├── src/
│   │   ├── api/
│   │   │   └── axios.ts
│   │   ├── assets/
│   │   │   └── react.svg
│   │   ├── components/
│   │   │   └── GlobalAxiosInterceptor.tsx
│   │   ├── context/
│   │   │   ├── AuthContext.tsx
│   │   │   └── ToastContext.tsx
│   │   ├── pages/
│   │   │   ├── AdminPanel.tsx
│   │   │   ├── Dashboard.tsx
│   │   │   ├── Login.tsx
│   │   │   └── Register.tsx
│   │   ├── App.css
│   │   ├── App.tsx
│   │   ├── index.css
│   │   └── main.tsx
│   ├── Dockerfile
│   ├── eslint.config.js
│   ├── index.html
│   ├── package-lock.json
│   ├── package.json
│   ├── tsconfig.app.json
│   ├── tsconfig.json
│   ├── tsconfig.node.json
│   └── vite.config.ts
├── docker-compose.yml
├── README.md
└── Project.md
```

---

## Module List

### Backend Modules

#### `backend/app/main.py`

- FastAPI application entry point
- Registers CORS middleware
- Connects/disconnects MongoDB on app lifecycle events
- Includes API routers for health, auth, tasks, and users

#### `backend/app/core/config.py`

- Loads environment settings via `pydantic-settings`
- Defines project name, MongoDB URL, DB name, JWT secret, algorithm, and token expiry

#### `backend/app/core/security.py`

- Password hash generation
- Password verification
- JWT access token creation with optional extra claims

#### `backend/app/core/dependencies.py`

- OAuth2 bearer token extraction
- Current user lookup from JWT `sub`
- Admin access enforcement dependency

#### `backend/app/db/mongodb.py`

- MongoDB client manager
- Async connect/close helpers
- Health check with `ping`
- Shared database dependency provider

#### `backend/app/routes/api/v1/auth.py`

- `POST /register`
- `POST /login`
- Handles account creation, duplicate email checks, password hashing, and JWT issuance

#### `backend/app/routes/api/v1/tasks.py`

- `POST /`
- `GET /`
- `PUT /{task_id}`
- `DELETE /{task_id}`
- `GET /all`
- Handles CRUD operations for tasks with owner/admin authorization rules

#### `backend/app/routes/api/v1/users.py`

- `GET /`
- `POST /`
- `GET /{user_id}`
- `PUT /{user_id}`
- `DELETE /{user_id}`
- Handles admin user management and controlled self/admin profile retrieval

#### `backend/app/routes/api/v1/health.py`

- `GET /health`
- Reports API database connectivity state

#### `backend/app/routes/api/v2/verify_db.py`

- Standalone script to verify MongoDB connectivity
- Used in CI validation flow

#### `backend/app/schemas/user.py`

- Pydantic request/response models for user creation, update, storage, and API responses
- Defines `UserRole` enum with `USER` and `ADMIN`

#### `backend/app/schemas/task.py`

- Pydantic request/response models for tasks
- Defines create, update, stored, and response payload shapes

#### `backend/app/models/user.py`

- User model representation for stored database documents

#### `backend/app/models/task.py`

- Task model representation for stored database documents

#### `backend/app/utils/logger.py`

- Colored console logger configuration
- Reduces duplicate handlers on app startup

### Frontend Modules

#### `frontend/src/main.tsx`

- Application bootstrap
- Wraps the app with router, auth provider, toast provider, and global interceptor

#### `frontend/src/App.tsx`

- Defines frontend routes
- Protects dashboard and admin pages behind authentication
- Redirects `/` to `/dashboard`

#### `frontend/src/api/axios.ts`

- Shared Axios client
- Configures API base URL
- Attaches bearer token automatically from `localStorage`

#### `frontend/src/components/GlobalAxiosInterceptor.tsx`

- Centralized response error handling
- Shows toast notifications for network, auth, authorization, and server errors
- Clears token and redirects to login on token expiry cases

#### `frontend/src/context/AuthContext.tsx`

- Stores authenticated user and token state
- Decodes JWT payload on startup
- Exposes `login`, `logout`, `isAuthenticated`, and loading state

#### `frontend/src/context/ToastContext.tsx`

- Global toast state manager
- Renders portal-based notification UI
- Supports success, error, and info messages

#### `frontend/src/pages/Login.tsx`

- User login form
- Sends OAuth2-form login request
- Stores JWT after successful login

#### `frontend/src/pages/Register.tsx`

- User registration form
- Validates password confirmation on client side
- Redirects to login after successful signup

#### `frontend/src/pages/Dashboard.tsx`

- Protected task dashboard
- Fetches user tasks
- Creates tasks
- Deletes tasks
- Shows system health and latency indicator
- Provides admin shortcut when logged in as admin

#### `frontend/src/pages/AdminPanel.tsx`

- Protected admin-only interface
- Lists users
- Creates, edits, and deletes users
- Assigns roles and permissions
- Displays summary cards and system status

### Infrastructure and Tooling Modules

#### `docker-compose.yml`

- Starts backend and frontend containers together

#### `backend/Dockerfile`

- Builds backend service with Python 3.11
- Runs FastAPI via `uvicorn`

#### `frontend/Dockerfile`

- Builds frontend with Node 24
- Runs Vite development server

#### `.github/workflows/ci.yml`

- Runs backend dependency installation and DB verification
- Starts backend in CI
- Builds frontend in CI

#### `docs/`

- Contains backend, frontend, schema, and scalability documentation
- Includes screenshots of working UI

---

## API Summary

### Health

- `GET /api/v1/health` - database-aware health check

### Auth

- `POST /api/v1/auth/register` - register a new user
- `POST /api/v1/auth/login` - login and receive JWT token

### Tasks

- `POST /api/v1/tasks/` - create task
- `GET /api/v1/tasks/` - list current user's tasks
- `PUT /api/v1/tasks/{task_id}` - update owned task
- `DELETE /api/v1/tasks/{task_id}` - delete owned task or any task if admin
- `GET /api/v1/tasks/all` - admin-only list of all tasks

### Users

- `GET /api/v1/users/` - admin-only list users
- `POST /api/v1/users/` - admin-only create user
- `GET /api/v1/users/{user_id}` - fetch own profile or any profile if admin
- `PUT /api/v1/users/{user_id}` - admin-only update user
- `DELETE /api/v1/users/{user_id}` - admin-only delete user

---

## Data Model Summary

### User

- `name`
- `email`
- `hashed_password`
- `role`
- `permissions`
- `created_at`

### Task

- `title`
- `description`
- `owner_id`
- `created_at`

---

## Observations

- The backend is modular and follows a clear FastAPI separation between config, dependencies, schemas, routes, and DB access.
- The frontend is organized by responsibility with separate folders for pages, shared context, components, and API utilities.
- The project supports both standard users and admins, with most advanced capabilities centered around admin user management.
- Some frontend comments mention an older health route assumption, but the actual backend currently exposes health at `/api/v1/health` through the `health` router.
- The frontend Axios base URL is currently hardcoded to the deployed Render backend, which is convenient for demos but less flexible for local development unless changed or made environment-based.

---

## Suggested High-Level Module Grouping

### Business Modules

- Authentication
- Authorization
- User management
- Task management

### Technical Modules

- API routing
- Security and token handling
- Database connection management
- Validation schemas
- Logging
- Frontend state management
- API client and interceptor handling
- DevOps and containerization
- CI/CD workflows
- Documentation and project analysis
- Testing (if implemented)
- Scalability and performance optimizations (if implemented)
- Monitoring and observability (if implemented)
- Error handling and resilience (if implemented)
- Deployment and hosting configurations (if implemented)
- API documentation and client generation (if implemented)
- Code quality and linting configurations (if implemented)
- Performance profiling and optimization tools (if implemented)
- Security hardening and vulnerability scanning (if implemented)
- Internationalization and localization (if implemented)
- Accessibility improvements (if implemented)
- User experience enhancements (if implemented)
- Feature flagging and A/B testing (if implemented)
