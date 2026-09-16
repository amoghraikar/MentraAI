from datetime import datetime
from typing import List
from pydantic import BaseModel, ConfigDict, Field


class NoteBase(BaseModel):
    subject_id: str
    topic_id: str | None = None
    title: str = Field(..., min_length=1, max_length=255)
    content: str = ""
    tags: List[str] = Field(default_factory=list)


class NoteCreate(NoteBase):
    pass


class NoteUpdate(BaseModel):
    subject_id: str | None = None
    topic_id: str | None = None
    title: str | None = Field(None, min_length=1, max_length=255)
    content: str | None = None
    tags: List[str] | None = None


class NoteResponse(NoteBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
