from pydantic import BaseModel, Field, BeforeValidator
from typing import Optional, Annotated
from datetime import datetime

PyObjectId = Annotated[str, BeforeValidator(str)]

class TaskModel(BaseModel):
    id: PyObjectId = Field(alias="_id")
    title: str
    description: Optional[str] = None
    owner_id: str
    created_at: datetime

    class Config:
        populate_by_name = True
        json_encoders = {datetime: lambda v: v.isoformat()}
