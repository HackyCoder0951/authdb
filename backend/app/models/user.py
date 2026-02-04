from pydantic import BaseModel, EmailStr, Field, BeforeValidator
from typing import Optional, Annotated, List
from enum import Enum
from datetime import datetime

PyObjectId = Annotated[str, BeforeValidator(str)]

class UserRole(str, Enum):
    USER = "USER"
    ADMIN = "ADMIN"

class UserModel(BaseModel):
    id: PyObjectId = Field(alias="_id")
    email: EmailStr
    hashed_password: str
    role: UserRole
    permissions: List[str] = []
    created_at: datetime
    
    class Config:
        populate_by_name = True
        json_encoders = {datetime: lambda v: v.isoformat()}
