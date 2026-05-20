from datetime import datetime
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from bson import ObjectId

from shared.db.mongodb import get_database
from shared import decode_access_token, get_password_hash
from ..schemas import UserCreate, UserResponse, UserUpdate, UserRole

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


async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security), db=Depends(get_database)):
    if credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid auth scheme")
    try:
        token_data = decode_access_token(credentials.credentials)
        user_id = token_data.get("sub")
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Could not validate credentials")

    if not user_id or not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Could not validate credentials")

    user = await db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user["_id"] = str(user["_id"])
    return UserResponse(**user)


async def get_current_active_admin(current_user: UserResponse = Depends(get_current_user)):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="The user doesn't have enough privileges")
    return current_user


@router.get("/", response_model=list[UserResponse])
async def read_users(skip: int = 0, limit: int = 100, current_user: UserResponse = Depends(get_current_active_admin), db=Depends(get_database)):
    logger.info(f"Admin {current_user.email} fetching users list")
    users = await db.users.find().skip(skip).limit(limit).to_list(length=limit)
    for user in users:
        user["_id"] = str(user["_id"])
    return [UserResponse(**user) for user in users]


@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user_admin(user_in: UserCreate, current_user: UserResponse = Depends(get_current_active_admin), db=Depends(get_database)):
    logger.info(f"Admin {current_user.email} creating new user: {user_in.email}")
    user = await db.users.find_one({"email": user_in.email})
    if user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")

    user_dict = user_in.dict()
    user_dict["hashed_password"] = get_password_hash(user_dict.pop("password"))
    user_dict["role"] = user_dict["role"].value
    user_dict["created_at"] = datetime.utcnow()

    result = await db.users.insert_one(user_dict)
    created_user = await db.users.find_one({"_id": result.inserted_id})
    created_user["_id"] = str(created_user["_id"])
    return UserResponse(**created_user)


@router.get("/{user_id}", response_model=UserResponse)
async def read_user(user_id: str, current_user: UserResponse = Depends(get_current_user), db=Depends(get_database)):
    if current_user.role != UserRole.ADMIN and current_user.id != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    object_id = validate_object_id(user_id, "user")
    user = await db.users.find_one({"_id": object_id})
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user["_id"] = str(user["_id"])
    return UserResponse(**user)


@router.put("/{user_id}", response_model=UserResponse)
async def update_user(user_id: str, user_in: UserUpdate, current_user: UserResponse = Depends(get_current_active_admin), db=Depends(get_database)):
    logger.info(f"Admin {current_user.email} updating user {user_id}")
    object_id = validate_object_id(user_id, "user")
    user = await db.users.find_one({"_id": object_id})
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    update_data = {k: v for k, v in user_in.dict(exclude_unset=True).items()}
    if update_data:
        if "role" in update_data:
            update_data["role"] = update_data["role"].value
        await db.users.update_one({"_id": object_id}, {"$set": update_data})

    updated_user = await db.users.find_one({"_id": object_id})
    updated_user["_id"] = str(updated_user["_id"])
    return UserResponse(**updated_user)


@router.delete("/{user_id}")
async def delete_user(user_id: str, current_user: UserResponse = Depends(get_current_active_admin), db=Depends(get_database)):
    logger.info(f"Admin {current_user.email} deleting user {user_id}")
    object_id = validate_object_id(user_id, "user")
    user = await db.users.find_one({"_id": object_id})
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    await db.users.delete_one({"_id": object_id})
    return {"message": "User deleted successfully"}
