from datetime import datetime
from typing import List
from pydantic import BaseModel, ConfigDict, Field


class GoalMilestoneBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    is_completed: bool = False


class GoalMilestoneCreate(GoalMilestoneBase):
    pass


class GoalMilestoneResponse(GoalMilestoneBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    goal_id: str
    created_at: datetime


class GoalBase(BaseModel):
    subject_id: str
    title: str = Field(..., min_length=1, max_length=255)
    target_date: datetime
    is_completed: bool = False


class GoalCreate(GoalBase):
    milestones: List[GoalMilestoneCreate] = Field(default_factory=list)


class GoalUpdate(BaseModel):
    subject_id: str | None = None
    title: str | None = Field(None, min_length=1, max_length=255)
    target_date: datetime | None = None
    is_completed: bool | None = None


class GoalResponse(GoalBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
    milestones: List[GoalMilestoneResponse] = Field(default_factory=list)
