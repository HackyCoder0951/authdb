import asyncio
from contextlib import suppress

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from shared.db.mongodb import mongodb
from .routes.health import router as health_router
from .routes.users import router as users_router
from .rpc_handlers import start_rpc_server

app = FastAPI(title="user-service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(users_router, prefix="/api/v1/users", tags=["users"])
app.include_router(health_router, prefix="/api/v1", tags=["health"])


@app.on_event("startup")
async def startup_event():
    await mongodb.connect_to_database()
    app.state.rpc_task = asyncio.create_task(start_rpc_server())


@app.on_event("shutdown")
async def shutdown_event():
    task = getattr(app.state, "rpc_task", None)
    if task:
        task.cancel()
        with suppress(asyncio.CancelledError):
            await task
    await mongodb.close_database_connection()
