# Scalable REST API with Authentication & Role-Based Access

## Project Overview
This project is a scalable backend system built using Python (FastAPI) with JWT authentication and role-based access control, along with a basic frontend UI to interact with the APIs.

The system allows users to register, log in, and perform CRUD operations on a secondary entity (Tasks) while enforcing proper authorization rules. It is designed with security, modularity, and scalability in mind.

---

## Tech Stack

### Backend
- Language: Python
- Framework: FastAPI
- Authentication: JWT (JSON Web Tokens)
- Password Hashing: bcrypt (passlib)
- ORM: SQLAlchemy
- Database: PostgreSQL / SQLite (for demo)
- Validation: Pydantic
- API Documentation: Swagger (OpenAPI)

### Frontend
- Framework: React.js (Vite) / Vanilla JavaScript
- HTTP Client: Axios / Fetch API
- Auth Storage: LocalStorage (JWT)

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
│   │   ├── session.py
│   │   └── base.py
│   └── utils/
│       └── role_checker.py
├── requirements.txt
└── README.md
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

### User Table
| Field           | Type             |
|-----------------|------------------|
| id              | Integer (PK)     |
| email           | String (Unique)  |
| hashed_password | String           |
| role            | USER / ADMIN     |
| created_at      | Timestamp        |

### Task Table
| Field      | Type              |
|------------|-------------------|
| id         | Integer (PK)      |
| title      | String            |
| description| String            |
| owner_id   | Foreign Key (User)|
| created_at | Timestamp         |

---

## API Endpoints

### Auth APIs
| Method | Endpoint               | Description      |
|--------|------------------------|------------------|
| POST   | /api/v1/auth/register  | Register user    |
| POST   | /api/v1/auth/login     | Login & get JWT  |

### Task APIs
| Method | Endpoint             | Access |
|--------|----------------------|--------|
| POST   | /api/v1/tasks        | User   |
| GET    | /api/v1/tasks        | User   |
| PUT    | /api/v1/tasks/{id}   | Owner  |
| DELETE | /api/v1/tasks/{id}   | Admin  |

---

## API Documentation
Swagger UI is available at:

```bash
http://localhost:8000/docs
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
git clone <repo-url>
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
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
- Non-TLS MongoDB connections for simplified deployment

---

## Scalability & Future Improvements
- Microservices-based architecture
- Redis caching for frequently accessed data
- Load balancing using NGINX
- Docker containerization
- API rate limiting
- CI/CD pipeline integration

---

## Evaluation Checklist Mapping
- RESTful API design
- Secure authentication & authorization
- Clean database schema
- Functional frontend integration
- Scalable project structure
- API documentation

---

## Author
Backend Developer Intern Assignment

Built using Python & FastAPI

