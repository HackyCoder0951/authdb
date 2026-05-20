from typing import Any

from shared import rpc_call

from .config import USER_RPC_QUEUE


async def get_user_by_id(user_id: str) -> dict[str, Any] | None:
    response = await rpc_call(
        USER_RPC_QUEUE,
        {"action": "get_user_by_id", "user_id": user_id},
    )
    if not response or response.get("error"):
        return None
    return response.get("user")
