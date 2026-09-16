from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.core.dependencies import get_current_user, get_db
from app.models.user import User
from app.schemas.goal import (
    GoalCreate,
    GoalMilestoneResponse,
    GoalResponse,
    GoalUpdate,
)
from app.services.goal_service import goal_service

router = APIRouter()


@router.get("", response_model=List[GoalResponse])
def get_goals(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve all goals for the authenticated user."""
    return goal_service.get_user_goals(db, user_id=current_user.id)


@router.post("", response_model=GoalResponse, status_code=status.HTTP_201_CREATED)
def create_goal(
    goal_in: GoalCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new study goal with optional milestones."""
    return goal_service.create_goal(db, user_id=current_user.id, goal_in=goal_in)


@router.get("/{goal_id}", response_model=GoalResponse)
def get_goal(
    goal_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve a specific goal by ID."""
    return goal_service.get_user_goal_by_id(
        db, goal_id=goal_id, user_id=current_user.id
    )


@router.put("/{goal_id}", response_model=GoalResponse)
def update_goal(
    goal_id: str,
    goal_in: GoalUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update goal status, title, or target date."""
    return goal_service.update_goal(
        db, goal_id=goal_id, user_id=current_user.id, goal_in=goal_in
    )


@router.delete("/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_goal(
    goal_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a goal."""
    goal_service.delete_goal(db, goal_id=goal_id, user_id=current_user.id)


@router.post("/{goal_id}/milestones/{milestone_id}/toggle", response_model=GoalMilestoneResponse)
def toggle_milestone(
    goal_id: str,
    milestone_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Toggle completion status of a goal milestone."""
    return goal_service.toggle_milestone(
        db, goal_id=goal_id, milestone_id=milestone_id, user_id=current_user.id
    )
