from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.core.dependencies import get_current_user, get_db
from app.models.user import User
from app.schemas.subject import (
    SubjectCreate,
    SubjectDetailResponse,
    SubjectResponse,
    SubjectUpdate,
)
from app.services.subject_service import subject_service

router = APIRouter()


@router.get("", response_model=List[SubjectDetailResponse])
def get_subjects(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve all subjects for the authenticated user."""
    return subject_service.get_user_subjects(db, user_id=current_user.id)


@router.post("", response_model=SubjectResponse, status_code=status.HTTP_201_CREATED)
def create_subject(
    subject_in: SubjectCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new subject for the authenticated user."""
    return subject_service.create_subject(
        db, user_id=current_user.id, subject_in=subject_in
    )


@router.get("/{subject_id}", response_model=SubjectDetailResponse)
def get_subject(
    subject_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve a single subject by ID."""
    return subject_service.get_user_subject_by_id(
        db, subject_id=subject_id, user_id=current_user.id
    )


@router.put("/{subject_id}", response_model=SubjectResponse)
def update_subject(
    subject_id: str,
    subject_in: SubjectUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update subject details."""
    return subject_service.update_subject(
        db, subject_id=subject_id, user_id=current_user.id, subject_in=subject_in
    )


@router.delete("/{subject_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_subject(
    subject_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a subject and all associated resources."""
    subject_service.delete_subject(db, subject_id=subject_id, user_id=current_user.id)
