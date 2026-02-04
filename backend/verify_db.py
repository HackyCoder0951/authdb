import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config import settings
# import certifi

async def verify():
    print(f"Connecting to {settings.MONGODB_URL}...")
    try:
        client = AsyncIOMotorClient(settings.MONGODB_URL)
        await client.admin.command('ping')
        print("SUCCESS: Connection verified!")
    except Exception as e:
        print(f"FAILURE: {e}")

if __name__ == "__main__":
    asyncio.run(verify())
