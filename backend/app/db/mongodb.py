from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config import settings

class MongoDB:
    client: AsyncIOMotorClient = None
    db = None

    async def connect_to_database(self):
        self.client = AsyncIOMotorClient(settings.MONGODB_URL)
        self.db = self.client[settings.DB_NAME]
        print("Connected to MongoDB")

    async def close_database_connection(self):
        if self.client:
            self.client.close()
            print("Closed MongoDB connection")

    async def check_connection(self) -> bool:
        if not self.client:
            return False
        try:
            await self.client.admin.command('ping')
            return True
        except Exception:
            return False

mongodb = MongoDB()

async def get_database():
    return mongodb.db
