# Scalable REST API with Authentication & Role-Based Access
### *Built using Python & FastAPI*
## Project Overview
This project is a scalable backend system built using Python (FastAPI) with JWT authentication and role-based access control, along with a basic frontend UI to interact with the APIs.

The system allows users to register, log in, and perform CRUD operations on a secondary entity (Tasks) while enforcing proper authorization rules. It is designed with security, modularity, and scalability in mind.

---

## Project Structure

```
backend/
├── app/
│   ├── main.py
│   ├── core/
│   │   ├── config.py
│   │   ├── security.py
│   │   └── dependencies.py
│   ├── models/
│   │   ├── user.py
│   │   └── task.py
│   ├── schemas/
│   │   ├── user.py
│   │   └── task.py
│   ├── routes/
│   │   ├── auth.py
│   │   ├── users.py
│   │   └── tasks.py
│   ├── db/
│   │   └── mongodb.py
│   ├── utils/
│   │   └── logger.py
│   └── Scalability_Guide.md
├── Dockerfile
├── requirements.txt
└── README.md
docs/
├── Back-End.md
├── Front-End.md
└── DB_Schema.md
frontend/
├── src/
│   ├── api/
│   ├── components/
│   ├── context/
│   ├── pages/
│   ├── App.tsx
│   └── main.tsx
├── package.json
├── vite.config.ts
├── Dockerfile
└── README.md
.github/
└── workflows/
    └── ci.yml
docker-compose.yml
```

---

## Authentication & Authorization

### Authentication
- User registration & login
- Passwords are hashed using bcrypt
- JWT tokens issued on successful login
- Tokens must be sent in headers:

```http
Authorization: Bearer <token>
```

### Role-Based Access
- USER: Can create and manage own tasks
- ADMIN: Can view and delete any task

---

## Database Schema

### User Schema
```
{
    "id": "Integer (PK)",
    "name": "String",
    "email": "String (Unique)",
    "permission": "String",
    "role": "USER / ADMIN",
    "hashed_password": "String",
    "created_at": "Timestamp"
}
```

### Task Schema
```
{
    "id": "Integer (PK)",
    "title": "String",
    "description": "String",
    "owner_id": "Foreign Key (User)",
    "created_at": "Timestamp"
}
```

---

## API Endpoints

### Health Check APIs
| Method | Endpoint               | Description      |
|--------|------------------------|------------------|
| GET    | /api/v1/health         | Health check     |

### Auth APIs
| Method | Endpoint               | Description      |
|--------|------------------------|------------------|
| POST   | /api/v1/auth/register  | Register user    |
| POST   | /api/v1/auth/login     | Login & get JWT  |

### Task APIs
| Method | Endpoint             | Access |
|--------|----------------------|--------|
| GET   | /api/v1/tasks        | User   |
| POST    | /api/v1/tasks        | User   |
| PUT   | /api/v1/tasks/{id}   | Owner  |
| DELETE | /api/v1/tasks/{id}   | Admin  |
| GET    | /api/v1/tasks        | User   |

### User APIs
| Method | Endpoint             | Access |
|--------|----------------------|--------|
| GET   | /api/v1/users        | User   |
| POST    | /api/v1/users        | User   |
| PUT   | /api/v1/users/{id}   | Owner  |
| DELETE | /api/v1/users/{id}   | Admin  |
| GET    | /api/v1/users        | Admin   |

---

## Docker Support

The project includes Dockerfiles for both backend and frontend.
Run both services using:

**``` docker-compose up --build ```**

---

## API Documentation
Swagger UI is available at:

```bash
http://localhost:8001/docs
```

A Postman collection is also provided for API testing.

---

## Input Validation & Error Handling
- All request bodies validated using Pydantic
- Proper HTTP status codes
- Centralized error handling
- Sanitized inputs to prevent injection attacks

---

## Frontend Features
- User registration & login
- JWT-based protected dashboard
- CRUD operations on tasks
- Display API success/error responses
- Simple and functional UI

---

## How to Run the Project

### Backend Setup
```bash
git clone https://github.com/HackyCoder0951/authdb.git
python -m venv .venv
cd backend
source .venv/bin/activate
pip install -r requirements.txt
# Ensure MongoDB is running locally or set MONGO_URI in .env
uvicorn app.main:app --host 0.0.0.0 --port 8001

```

### Frontend Setup
```bash
cd frontend
npm install
npm run dev
```

---

## Security Practices
- Password hashing (bcrypt)
- JWT expiry & verification
- Role-based access control
- Input validation
- ORM-based database access

---

## Scalability & Future Improvements
- **Scalability Guide**: A detailed guide (`app/Scalability_Guide.md`) is included to assist with understanding microservices, caching (Redis), and load balancing.
- Microservices-based architecture (Proposed)
- Redis caching for frequently accessed data (Proposed)
- Load balancing using NGINX (Proposed)
- **Advanced Logging**: Custom logging utility for better observability.
- Docker containerization
- API rate limiting
## Detailed Documentation
For deep dives into specific areas, please refer to the `docs/` directory:
- **[Backend Architecture](docs/Back-End.md)**: Logic flow, Auth, and Task management.
- **[Frontend Architecture](docs/Front-End.md)**: Component structure and State management.
- **[Database Schema](docs/DB_Schema.md)**: ERD diagrams and Collection details.

## CI/CD Pipeline
Automated testing and build pipelines are implemented using **GitHub Actions**.
- **Config**: `.github/workflows/ci.yml`
- **Backend**: Runs unit tests and verifies API health.
- **Frontend**: Installs dependencies and checks build status.

---

## Evaluation Checklist Mapping
- RESTful API design
- Secure authentication & authorization
- Clean database schema
- Functional frontend integration
- Scalable project structure
- API documentation

---
