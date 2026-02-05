from fastapi import FastAPI
from app.routes.api.v1 import auth, tasks, users, health
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.db.mongodb import mongodb
from app.utils.logger import setup_logging

# Configure Logging using custom utility
logger = setup_logging()

app = FastAPI(title=settings.PROJECT_NAME, redirect_slashes=False)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # In production, set to frontend domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database Events
@app.on_event("startup")
async def startup_db_client():
    logger.info("Starting up application...")
    await mongodb.connect_to_database()
    logger.info("Database connection established.")

@app.on_event("shutdown")
async def shutdown_db_client():
    logger.info("Shutting down application...")
    await mongodb.close_database_connection()
    logger.info("Database connection closed.")

app.include_router(health.router, prefix="/api/v1", tags=["Health"])
app.include_router(auth.router, prefix="/api/v1/auth", tags=["Auth"])
app.include_router(tasks.router, prefix="/api/v1/tasks", tags=["Tasks"])
app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])

@app.get("/")
async def root():
    return {"message": "Welcome to AuthDB API"}
