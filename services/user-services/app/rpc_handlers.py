import os
import json
import asyncio
import logging
import aio_pika
from bson import ObjectId

from shared.db.mongodb import get_database

RABBITMQ_URL = os.getenv("RABBITMQ_URL", "amqp://guest:guest@localhost/")
QUEUE_NAME = os.getenv("USER_RPC_QUEUE", "user_rpc_queue")
logger = logging.getLogger(__name__)


def serialize_user(user: dict) -> dict:
    user["_id"] = str(user["_id"])
    if hasattr(user.get("role"), "value"):
        user["role"] = user["role"].value
    if user.get("created_at"):
        user["created_at"] = user["created_at"].isoformat()
    return user


async def handle_rpc_message(message: aio_pika.IncomingMessage):
    async with message.process():
        payload = json.loads(message.body.decode("utf-8"))
        action = payload.get("action")
        response = {"error": "unknown action"}
        db = await get_database()

        if action == "get_user_by_id":
            user_id = payload.get("user_id")
            if user_id and ObjectId.is_valid(user_id):
                user = await db.users.find_one({"_id": ObjectId(user_id)})
                if user:
                    response = {"user": serialize_user(user)}
                else:
                    response = {"error": "User not found"}
            else:
                response = {"error": "Invalid user id"}

        elif action == "validate_user":
            email = payload.get("email")
            user = await db.users.find_one({"email": email}) if email else None
            response = {"valid": bool(user)}

        if message.reply_to:
            await message.channel.default_exchange.publish(
                aio_pika.Message(
                    body=json.dumps(response).encode("utf-8"),
                    correlation_id=message.correlation_id,
                ),
                routing_key=message.reply_to,
            )


async def start_rpc_server():
    while True:
        connection = None
        try:
            connection = await aio_pika.connect_robust(RABBITMQ_URL)
            channel = await connection.channel()
            queue = await channel.declare_queue(QUEUE_NAME, durable=True)
            await queue.consume(handle_rpc_message)
            logger.info("User RPC server listening on queue %s", QUEUE_NAME)
            await asyncio.Future()
        except asyncio.CancelledError:
            if connection:
                await connection.close()
            raise
        except Exception as exc:
            logger.warning("User RPC server unavailable, retrying: %s", exc)
            if connection:
                await connection.close()
            await asyncio.sleep(5)
