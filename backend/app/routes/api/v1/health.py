from fastapi import APIRouter
from app.db.mongodb import mongodb

router = APIRouter()

# Routes
@router.get("/health", tags=["Health"])
async def health_check():
    is_connected = await mongodb.check_connection()
    if is_connected:
        return {"status": "ok", "database": "connected"}
    return {"status": "error", "database": "disconnected"}