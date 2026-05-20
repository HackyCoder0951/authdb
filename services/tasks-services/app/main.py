from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from shared.db.mongodb import mongodb
from .config import SERVICE_NAME
from .routes.health import router as health_router
from .routes.tasks import router as tasks_router

app = FastAPI(title=SERVICE_NAME)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(tasks_router, prefix="/api/v1/tasks", tags=["tasks"])
app.include_router(health_router, prefix="/api/v1", tags=["health"])


@app.on_event("startup")
async def startup_event():
    await mongodb.connect_to_database()
    await mongodb.db.tasks.create_index("owner_id")


@app.on_event("shutdown")
async def shutdown_event():
    await mongodb.close_database_connection()
