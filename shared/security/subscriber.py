import os
import json
import aio_pika
from typing import Callable, Any

RABBITMQ_URL = os.getenv("RABBITMQ_URL", "amqp://guest:guest@localhost/")


async def consume_queue(queue_name: str, handler: Callable[[dict[str, Any]], Any]):
	connection = await aio_pika.connect_robust(RABBITMQ_URL)
	async with connection:
		channel = await connection.channel()
		queue = await channel.declare_queue(queue_name, durable=True)

		async with queue.iterator() as queue_iter:
			async for message in queue_iter:
				async with message.process():
					payload = json.loads(message.body.decode("utf-8"))
					await handler(payload)
