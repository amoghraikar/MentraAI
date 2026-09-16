from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field


class StudySessionBase(BaseModel):
    subject_id: str
    topic_id: str | None = None
    target_duration_minutes: int = Field(45, ge=1)
    actual_duration_minutes: int = Field(..., ge=0)
    study_mode: str = "Focus Mode"
    is_focus_monitoring_enabled: bool = True
    focus_score: int = Field(100, ge=0, le=100)
    distractions_count: int = Field(0, ge=0)
    reflection: str = "good"
    started_at: datetime
    ended_at: datetime


class StudySessionCreate(StudySessionBase):
    pass


class StudySessionResponse(StudySessionBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    created_at: datetime
