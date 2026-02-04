from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from app.db.mongodb import get_database
from app.schemas.user import UserCreate, UserResponse, UserUpdate, UserRole
from app.core.dependencies import get_current_user, get_current_active_admin
from app.core.security import get_password_hash
from bson import ObjectId
from datetime import datetime
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

@router.get("/", response_model=List[UserResponse])
async def read_users(
    skip: int = 0,
    limit: int = 100,
    current_user: UserResponse = Depends(get_current_active_admin),
    db = Depends(get_database)
):
    logger.info(f"Admin {current_user.email} fetching users list")
    users = await db.users.find().skip(skip).limit(limit).to_list(length=limit)
    for user in users:
        user["_id"] = str(user["_id"])
    return [UserResponse(**user) for user in users]

@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user_admin(
    user_in: UserCreate,
    current_user: UserResponse = Depends(get_current_active_admin),
    db = Depends(get_database)
):
    logger.info(f"Admin {current_user.email} creating new user: {user_in.email}")
    user = await db.users.find_one({"email": user_in.email})
    if user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
    
    user_dict = user_in.dict()
    hashed_password = get_password_hash(user_dict.pop("password"))
    user_dict["hashed_password"] = hashed_password
    user_dict["created_at"] = datetime.utcnow()
    # Ensure role is set (defaults to USER in schema if not provided, but Admin can set it)
    
    result = await db.users.insert_one(user_dict)
    
    created_user = await db.users.find_one({"_id": result.inserted_id})
    created_user["_id"] = str(created_user["_id"])
    return UserResponse(**created_user)

@router.get("/{user_id}", response_model=UserResponse)
async def read_user(
    user_id: str,
    current_user: UserResponse = Depends(get_current_user),
    db = Depends(get_database)
):
    # Allow admin or the user themselves
    if current_user.role != UserRole.ADMIN and current_user.id != user_id:
         raise HTTPException(status_code=403, detail="Not authorized")

    user = await db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    user["_id"] = str(user["_id"])
    return UserResponse(**user)

@router.put("/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: str,
    user_in: UserUpdate,
    current_user: UserResponse = Depends(get_current_active_admin), # Only admin can update permissions/roles via this endpoint for now
    db = Depends(get_database)
):
    logger.info(f"Admin {current_user.email} updating user {user_id}")
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    update_data = {k: v for k, v in user_in.dict(exclude_unset=True).items()}
    
    if update_data:
        await db.users.update_one({"_id": ObjectId(user_id)}, {"$set": update_data})
        
    updated_user = await db.users.find_one({"_id": ObjectId(user_id)})
    updated_user["_id"] = str(updated_user["_id"])
    return UserResponse(**updated_user)

@router.delete("/{user_id}")
async def delete_user(
    user_id: str,
    current_user: UserResponse = Depends(get_current_active_admin),
    db = Depends(get_database)
):
    logger.info(f"Admin {current_user.email} deleting user {user_id}")
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    await db.users.delete_one({"_id": ObjectId(user_id)})
    return {"message": "User deleted successfully"}
