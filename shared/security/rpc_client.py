import os
import json
import aio_pika
from typing import Any

RABBITMQ_URL = os.getenv("RABBITMQ_URL", "amqp://guest:guest@localhost/")


async def rpc_call(queue_name: str, payload: dict[str, Any], timeout: int = 5) -> Any:
	connection = await aio_pika.connect_robust(RABBITMQ_URL)
	async with connection:
		channel = await connection.channel()
		callback_queue = await channel.declare_queue(exclusive=True)

		correlation_id = str(id(payload))

		await channel.default_exchange.publish(
			aio_pika.Message(
				body=json.dumps(payload).encode("utf-8"),
				reply_to=callback_queue.name,
				correlation_id=correlation_id,
			),
			routing_key=queue_name,
		)

		with await callback_queue.iterator() as queue_iter:
			async for message in queue_iter:
				async with message.process():
					if message.correlation_id == correlation_id:
						return json.loads(message.body.decode("utf-8"))

	return None
