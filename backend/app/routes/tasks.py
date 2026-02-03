from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from app.db.mongodb import get_database
from app.schemas.task import TaskCreate, TaskUpdate, TaskResponse
from app.schemas.user import UserResponse
from app.core.dependencies import get_current_user, get_current_active_admin
from bson import ObjectId
from datetime import datetime
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

@router.post("/", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
async def create_task(task_in: TaskCreate, current_user: UserResponse = Depends(get_current_user), db = Depends(get_database)):
    logger.info(f"Creating task for user: {current_user.email}")
    task_dict = task_in.dict()
    task_dict["owner_id"] = current_user.id
    task_dict["created_at"] = datetime.utcnow()
    
    result = await db.tasks.insert_one(task_dict)
    
    created_task = await db.tasks.find_one({"_id": result.inserted_id})
    created_task["_id"] = str(created_task["_id"])
    logger.info(f"Task created successfully. ID: {created_task['_id']}")
    return TaskResponse(**created_task)

@router.get("/", response_model=List[TaskResponse])
async def read_tasks(current_user: UserResponse = Depends(get_current_user), db = Depends(get_database)):
    logger.info(f"Fetching tasks for user: {current_user.email}")
    tasks = await db.tasks.find({"owner_id": current_user.id}).to_list(length=100)
    for task in tasks:
        task["_id"] = str(task["_id"])
    return [TaskResponse(**task) for task in tasks]

@router.put("/{task_id}", response_model=TaskResponse)
async def update_task(task_id: str, task_in: TaskUpdate, current_user: UserResponse = Depends(get_current_user), db = Depends(get_database)):
    logger.info(f"Updating task {task_id} for user {current_user.email}")
    task = await db.tasks.find_one({"_id": ObjectId(task_id)})
    if not task:
        logger.warning(f"Task not found: {task_id}")
        raise HTTPException(status_code=404, detail="Task not found")
    
    if task["owner_id"] != current_user.id:
        logger.warning(f"Unauthorized update attempt on task {task_id} by user {current_user.email}")
        raise HTTPException(status_code=403, detail="Not authorized to update this task")
    
    update_data = {k: v for k, v in task_in.dict(exclude_unset=True).items()}
    
    if update_data:
        await db.tasks.update_one({"_id": ObjectId(task_id)}, {"$set": update_data})
        
    updated_task = await db.tasks.find_one({"_id": ObjectId(task_id)})
    updated_task["_id"] = str(updated_task["_id"])
    return TaskResponse(**updated_task)

@router.delete("/{task_id}")
async def delete_task(task_id: str, current_user: UserResponse = Depends(get_current_user), db = Depends(get_database)):
    logger.info(f"Deleting task {task_id} requested by {current_user.email}")
    task = await db.tasks.find_one({"_id": ObjectId(task_id)})
    if not task:
        logger.warning(f"Task not found: {task_id}")
        raise HTTPException(status_code=404, detail="Task not found")
    
    # Allow Admin to delete any task, or User to delete their own
    if current_user.role != "ADMIN" and task["owner_id"] != current_user.id:
        logger.warning(f"Unauthorized delete attempt on task {task_id} by user {current_user.email}")
        raise HTTPException(status_code=403, detail="Not authorized to delete this task")
        
    await db.tasks.delete_one({"_id": ObjectId(task_id)})
    logger.info(f"Task {task_id} deleted successfully")
    return {"message": "Task deleted successfully"}

# Admin only endpoint to view all tasks
@router.get("/all", response_model=List[TaskResponse])
async def read_all_tasks(current_user: UserResponse = Depends(get_current_active_admin), db = Depends(get_database)):
    logger.info(f"Admin {current_user.email} fetching all tasks")
    tasks = await db.tasks.find().to_list(length=100)
    for task in tasks:
        task["_id"] = str(task["_id"])
    return [TaskResponse(**task) for task in tasks]
