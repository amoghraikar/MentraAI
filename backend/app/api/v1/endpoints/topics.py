from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.core.dependencies import get_current_user, get_db
from app.models.user import User
from app.schemas.topic import TopicCreate, TopicResponse, TopicUpdate
from app.services.topic_service import topic_service

router = APIRouter()


@router.get("/by-subject/{subject_id}", response_model=List[TopicResponse])
def get_topics_by_subject(
    subject_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve all topics under a specific subject."""
    return topic_service.get_topics_by_subject(
        db, subject_id=subject_id, user_id=current_user.id
    )


@router.post("", response_model=TopicResponse, status_code=status.HTTP_201_CREATED)
def create_topic(
    topic_in: TopicCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new topic under a subject owned by the authenticated user."""
    return topic_service.create_topic(db, user_id=current_user.id, topic_in=topic_in)


@router.get("/{topic_id}", response_model=TopicResponse)
def get_topic(
    topic_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve a topic by ID."""
    return topic_service.get_topic_by_id(
        db, topic_id=topic_id, user_id=current_user.id
    )


@router.put("/{topic_id}", response_model=TopicResponse)
def update_topic(
    topic_id: str,
    topic_in: TopicUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update topic progress, completion, or content."""
    return topic_service.update_topic(
        db, topic_id=topic_id, user_id=current_user.id, topic_in=topic_in
    )


@router.delete("/{topic_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_topic(
    topic_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a topic."""
    topic_service.delete_topic(db, topic_id=topic_id, user_id=current_user.id)
