from app.schemas.auth import LoginRequest, TokenPayload, TokenResponse
from app.schemas.user import UserBase, UserCreate, UserResponse
from app.schemas.subject import SubjectBase, SubjectCreate, SubjectUpdate, SubjectResponse, SubjectDetailResponse
from app.schemas.topic import TopicBase, TopicCreate, TopicUpdate, TopicResponse
from app.schemas.note import NoteBase, NoteCreate, NoteUpdate, NoteResponse
from app.schemas.goal import (
    GoalBase,
    GoalCreate,
    GoalUpdate,
    GoalResponse,
    GoalMilestoneBase,
    GoalMilestoneCreate,
    GoalMilestoneResponse,
)
from app.schemas.study_session import StudySessionBase, StudySessionCreate, StudySessionResponse

__all__ = [
    "LoginRequest",
    "TokenPayload",
    "TokenResponse",
    "UserBase",
    "UserCreate",
    "UserResponse",
    "SubjectBase",
    "SubjectCreate",
    "SubjectUpdate",
    "SubjectResponse",
    "SubjectDetailResponse",
    "TopicBase",
    "TopicCreate",
    "TopicUpdate",
    "TopicResponse",
    "NoteBase",
    "NoteCreate",
    "NoteUpdate",
    "NoteResponse",
    "GoalBase",
    "GoalCreate",
    "GoalUpdate",
    "GoalResponse",
    "GoalMilestoneBase",
    "GoalMilestoneCreate",
    "GoalMilestoneResponse",
    "StudySessionBase",
    "StudySessionCreate",
    "StudySessionResponse",
]
