"""Shared code package for authdb microservices."""

from .models.user import UserCreate, UserResponse, UserUpdate, UserRole
from .models.task import TaskCreate, TaskResponse, TaskUpdate
from .db.mongodb import get_database
from .security import create_access_token, decode_access_token, get_password_hash, verify_password
from .messaging import publish_event, consume_queue, rpc_call

__all__ = [
    "UserCreate",
    "UserResponse",
    "UserUpdate",
    "UserRole",
    "TaskCreate",
    "TaskResponse",
    "TaskUpdate",
    "get_database",
    "create_access_token",
    "decode_access_token",
    "get_password_hash",
    "verify_password",
    "publish_event",
    "consume_queue",
    "rpc_call",
]
