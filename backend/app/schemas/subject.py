from datetime import datetime
from typing import List
from pydantic import BaseModel, ConfigDict, Field
from app.schemas.topic import TopicResponse


class SubjectBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    code: str = Field(..., min_length=1, max_length=50)
    description: str = ""
    color_hex: str = Field(default="#4F46E5", max_length=20)
    total_hours: float = Field(0.0, ge=0.0)
    target_hours: float = Field(20.0, gt=0.0)


class SubjectCreate(SubjectBase):
    pass


class SubjectUpdate(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=255)
    code: str | None = Field(None, min_length=1, max_length=50)
    description: str | None = None
    color_hex: str | None = Field(None, max_length=20)
    total_hours: float | None = Field(None, ge=0.0)
    target_hours: float | None = Field(None, gt=0.0)


class SubjectResponse(SubjectBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime


class SubjectDetailResponse(SubjectResponse):
    topics: List[TopicResponse] = Field(default_factory=list)
