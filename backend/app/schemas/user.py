from pydantic import BaseModel, EmailStr, Field, BeforeValidator
from typing import Optional, Annotated
from enum import Enum
from datetime import datetime

PyObjectId = Annotated[str, BeforeValidator(str)]

class UserRole(str, Enum):
    USER = "USER"
    ADMIN = "ADMIN"

class UserBase(BaseModel):
    name: Optional[str] = None
    email: EmailStr
    permissions: list[str] = []

class UserCreate(UserBase):
    password: str
    role: UserRole = UserRole.USER

class UserUpdate(BaseModel):
    name: Optional[str] = None
    role: Optional[UserRole] = None
    permissions: Optional[list[str]] = None

class UserInDB(UserBase):
    id: PyObjectId = Field(alias="_id")
    hashed_password: str
    role: UserRole
    created_at: datetime
    
    class Config:
        populate_by_name = True
        json_encoders = {datetime: lambda v: v.isoformat()}

class UserResponse(UserBase):
    id: PyObjectId = Field(alias="_id")
    role: UserRole
    created_at: datetime

    class Config:
        populate_by_name = True
        json_encoders = {datetime: lambda v: v.isoformat()}
