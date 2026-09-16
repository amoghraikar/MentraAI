from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from app.core.dependencies import get_current_user, get_db
from app.models.user import User
from app.schemas.study_session import StudySessionCreate, StudySessionResponse
from app.services.study_session_service import study_session_service

router = APIRouter()


@router.get("", response_model=List[StudySessionResponse])
def get_sessions(
    subject_id: Optional[str] = Query(None, description="Filter sessions by subject"),
    limit: int = Query(50, ge=1, le=100, description="Max records to return"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve study session history for the authenticated user."""
    return study_session_service.get_user_sessions(
        db, user_id=current_user.id, subject_id=subject_id, limit=limit
    )


@router.post("", response_model=StudySessionResponse, status_code=status.HTTP_201_CREATED)
def record_session(
    session_in: StudySessionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Record a completed study session with focus metrics and reflection."""
    return study_session_service.record_session(
        db, user_id=current_user.id, session_in=session_in
    )


@router.get("/{session_id}", response_model=StudySessionResponse)
def get_session(
    session_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve details of a specific study session."""
    return study_session_service.get_user_session_by_id(
        db, session_id=session_id, user_id=current_user.id
    )
