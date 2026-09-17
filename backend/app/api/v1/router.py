from fastapi import APIRouter
from app.api.v1.endpoints import (
    ai_coach,
    analytics,
    auth,
    goals,
    health,
    notes,
    sessions,
    subjects,
    topics,
    users,
)

api_router = APIRouter()

api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(subjects.router, prefix="/subjects", tags=["subjects"])
api_router.include_router(topics.router, prefix="/topics", tags=["topics"])
api_router.include_router(notes.router, prefix="/notes", tags=["notes"])
api_router.include_router(goals.router, prefix="/goals", tags=["goals"])
api_router.include_router(sessions.router, prefix="/sessions", tags=["sessions"])
api_router.include_router(ai_coach.router, prefix="/ai-coach", tags=["ai-coach"])
api_router.include_router(analytics.router, prefix="/analytics", tags=["analytics"])
