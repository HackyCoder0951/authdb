from datetime import datetime
import logging
from typing import Any

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from shared import decode_access_token
from shared.db.mongodb import get_database
from ..schemas import TaskCreate, TaskResponse, TaskUpdate, UserRole

router = APIRouter()
logger = logging.getLogger(__name__)
security = HTTPBearer()


def validate_object_id(value: str, resource_name: str = "Resource") -> ObjectId:
    if not ObjectId.is_valid(value):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid {resource_name} id",
        )
    return ObjectId(value)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db=Depends(get_database),
) -> dict[str, Any]:
    if credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid auth scheme",
        )

    try:
        token_data = decode_access_token(credentials.credentials)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
        )

    user_id = token_data.get("sub")
    if not user_id or not ObjectId.is_valid(user_id):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
        )

    user = await db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return {
        "id": str(user_id),
        "role": user.get("role", UserRole.USER.value),
        "email": user.get("email"),
        "name": user.get("name"),
        "permissions": user.get("permissions", []),
    }


def is_admin(user: dict[str, Any]) -> bool:
    return user.get("role") == UserRole.ADMIN.value


def has_permission(user: dict[str, Any], permission: str) -> bool:
    return permission in (user.get("permissions") or [])


def require_permission(user: dict[str, Any], permission: str) -> None:
    if is_admin(user):
        return
    if not has_permission(user, permission):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="The user doesn't have enough privileges",
        )


def serialize_task(task: dict[str, Any]) -> TaskResponse:
    task["_id"] = str(task["_id"])
    return TaskResponse(**task)


async def get_owned_task_or_404(task_id: str, current_user: dict[str, Any], db) -> dict[str, Any]:
    object_id = validate_object_id(task_id, "task")
    task = await db.tasks.find_one({"_id": object_id})
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found",
        )

    if task["owner_id"] != current_user["id"] and not is_admin(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized",
        )

    return task


@router.post("/", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
async def create_task(
    task_in: TaskCreate,
    current_user: dict[str, Any] = Depends(get_current_user),
    db=Depends(get_database),
):
    require_permission(current_user, "write:tasks")
    logger.info("Creating task for user %s", current_user["id"])
    task_dict = task_in.dict()
    task_dict["owner_id"] = current_user["id"]
    task_dict["created_at"] = datetime.utcnow()

    result = await db.tasks.insert_one(task_dict)
    created_task = await db.tasks.find_one({"_id": result.inserted_id})
    return serialize_task(created_task)


@router.get("/", response_model=list[TaskResponse])
async def read_tasks(
    skip: int = 0,
    limit: int = 100,
    current_user: dict[str, Any] = Depends(get_current_user),
    db=Depends(get_database),
):
    require_permission(current_user, "read:tasks")
    logger.info("Fetching tasks for user %s", current_user["id"])
    tasks = (
        await db.tasks.find({"owner_id": current_user["id"]})
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
        .to_list(length=limit)
    )
    return [serialize_task(task) for task in tasks]


@router.get("/all", response_model=list[TaskResponse])
async def read_all_tasks(
    skip: int = 0,
    limit: int = 100,
    current_user: dict[str, Any] = Depends(get_current_user),
    db=Depends(get_database),
):
    if not is_admin(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="The user doesn't have enough privileges",
        )

    logger.info("Admin %s fetching all tasks", current_user.get("email") or current_user["id"])
    tasks = (
        await db.tasks.find()
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
        .to_list(length=limit)
    )
    return [serialize_task(task) for task in tasks]


@router.get("/{task_id}", response_model=TaskResponse)
async def read_task(
    task_id: str,
    current_user: dict[str, Any] = Depends(get_current_user),
    db=Depends(get_database),
):
    require_permission(current_user, "read:tasks")
    task = await get_owned_task_or_404(task_id, current_user, db)
    return serialize_task(task)


@router.put("/{task_id}", response_model=TaskResponse)
async def update_task(
    task_id: str,
    task_in: TaskUpdate,
    current_user: dict[str, Any] = Depends(get_current_user),
    db=Depends(get_database),
):
    require_permission(current_user, "write:tasks")
    task = await get_owned_task_or_404(task_id, current_user, db)
    if task["owner_id"] != current_user["id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the task owner can update this task",
        )

    update_data = task_in.dict(exclude_unset=True)
    if update_data:
        await db.tasks.update_one(
            {"_id": task["_id"]},
            {"$set": update_data},
        )

    updated_task = await db.tasks.find_one({"_id": task["_id"]})
    return serialize_task(updated_task)


@router.delete("/{task_id}")
async def delete_task(
    task_id: str,
    current_user: dict[str, Any] = Depends(get_current_user),
    db=Depends(get_database),
):
    require_permission(current_user, "delete:tasks")
    task = await get_owned_task_or_404(task_id, current_user, db)
    await db.tasks.delete_one({"_id": task["_id"]})
    return {"message": "Task deleted successfully"}
