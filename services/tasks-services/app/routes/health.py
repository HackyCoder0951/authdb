from fastapi import APIRouter

from shared.db.mongodb import mongodb

router = APIRouter()


@router.get("/health")
async def health_check():
    connected = await mongodb.check_connection()
    return {"status": "ok" if connected else "error"}
