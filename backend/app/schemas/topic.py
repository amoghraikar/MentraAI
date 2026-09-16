from datetime import datetime
from typing import List
from pydantic import BaseModel, ConfigDict, Field


class TopicBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: str = ""
    progress: float = Field(0.0, ge=0.0, le=1.0)
    total_minutes: int = Field(0, ge=0)
    key_concepts: List[str] = Field(default_factory=list)
    notes_snippet: str = ""
    is_completed: bool = False


class TopicCreate(TopicBase):
    subject_id: str


class TopicUpdate(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=255)
    description: str | None = None
    progress: float | None = Field(None, ge=0.0, le=1.0)
    total_minutes: int | None = Field(None, ge=0)
    key_concepts: List[str] | None = None
    notes_snippet: str | None = None
    is_completed: bool | None = None


class TopicResponse(TopicBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    subject_id: str
    created_at: datetime
    updated_at: datetime
