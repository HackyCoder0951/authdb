from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from shared.db.mongodb import mongodb
from .routes.auth import router as auth_router
from .routes.health import router as health_router

app = FastAPI(title="auth-service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(health_router, prefix="/api/v1", tags=["health"])


@app.on_event("startup")
async def startup_event():
    await mongodb.connect_to_database()


@app.on_event("shutdown")
async def shutdown_event():
    await mongodb.close_database_connection()
