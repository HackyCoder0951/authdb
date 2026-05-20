from datetime import datetime, timedelta
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm

from shared.db.mongodb import get_database
from shared import create_access_token, get_password_hash, verify_password, publish_event
from ..schemas import UserCreate, UserResponse

router = APIRouter()
logger = logging.getLogger(__name__)


async def publish_auth_event(exchange_name: str, routing_key: str, message_body: dict):
    try:
        await publish_event(exchange_name, routing_key, message_body)
    except Exception as exc:
        logger.warning("Failed to publish auth event %s: %s", routing_key, exc)


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(user_in: UserCreate, db=Depends(get_database)):
    logger.info(f"Attempting to register user: {user_in.email}")
    user = await db.users.find_one({"email": user_in.email})
    if user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    user_dict = user_in.dict()
    hashed_password = get_password_hash(user_dict.pop("password"))
    user_dict["hashed_password"] = hashed_password
    user_dict["role"] = user_dict["role"].value
    user_dict["created_at"] = datetime.utcnow()

    result = await db.users.insert_one(user_dict)
    created_user = await db.users.find_one({"_id": result.inserted_id})
    created_user["_id"] = str(created_user["_id"])

    await publish_auth_event(
        exchange_name="auth_events",
        routing_key="user.created",
        message_body={
            "user_id": str(result.inserted_id),
            "email": user_in.email,
            "role": user_in.role.value,
            "created_at": created_user["created_at"].isoformat(),
        },
    )

    return UserResponse(**created_user)


@router.post("/login")
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db=Depends(get_database)):
    logger.info(f"Login attempt for user: {form_data.username}")
    user = await db.users.find_one({"email": form_data.username})
    if not user or not verify_password(form_data.password, user["hashed_password"]):
        logger.warning(f"Failed login attempt for user: {form_data.username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token_expires = timedelta(minutes=30)
    role = user["role"].value if hasattr(user["role"], "value") else user["role"]
    access_token = create_access_token(
        subject=str(user["_id"]),
        expires_delta=access_token_expires,
        claims={"role": role, "name": user.get("name"), "email": user["email"]},
    )

    await publish_auth_event(
        exchange_name="auth_events",
        routing_key="user.verified",
        message_body={
            "user_id": str(user["_id"]),
            "email": user["email"],
            "logged_in_at": datetime.utcnow().isoformat(),
        },
    )

    return {"access_token": access_token, "token_type": "bearer"}
