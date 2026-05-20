import os
from motor.motor_asyncio import AsyncIOMotorClient

MONGODB_URL = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
DB_NAME = os.getenv("DB_NAME", "auth_scaleDB")


class MongoDB:
    client: AsyncIOMotorClient = None
    db = None

    async def connect_to_database(self):
        if self.client is None:
            self.client = AsyncIOMotorClient(MONGODB_URL)
            self.db = self.client[DB_NAME]
            print(f"Connected to MongoDB at {MONGODB_URL}")

    async def close_database_connection(self):
        if self.client:
            self.client.close()
            self.client = None
            self.db = None
            print("Closed MongoDB connection")

    async def check_connection(self) -> bool:
        if not self.client:
            return False
        try:
            await self.client.admin.command("ping")
            return True
        except Exception:
            return False


mongodb = MongoDB()


async def get_database():
    if mongodb.db is None:
        await mongodb.connect_to_database()
    return mongodb.db
