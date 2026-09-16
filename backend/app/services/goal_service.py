from typing import Sequence
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from app.models.goal import Goal, GoalMilestone
from app.repositories.goal_repository import goal_repository
from app.repositories.subject_repository import subject_repository
from app.schemas.goal import GoalCreate, GoalUpdate


class GoalService:
    def get_user_goals(self, db: Session, user_id: str) -> Sequence[Goal]:
        return goal_repository.get_all_by_user(db, user_id=user_id)

    def get_user_goal_by_id(self, db: Session, goal_id: str, user_id: str) -> Goal:
        goal = goal_repository.get_by_id(db, goal_id=goal_id, user_id=user_id)
        if not goal:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Goal not found.",
            )
        return goal

    def create_goal(self, db: Session, user_id: str, goal_in: GoalCreate) -> Goal:
        subject = subject_repository.get_by_id(db, subject_id=goal_in.subject_id, user_id=user_id)
        if not subject:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subject not found or access denied.",
            )
        return goal_repository.create(db, user_id=user_id, goal_in=goal_in)

    def update_goal(
        self, db: Session, goal_id: str, user_id: str, goal_in: GoalUpdate
    ) -> Goal:
        goal = self.get_user_goal_by_id(db, goal_id=goal_id, user_id=user_id)
        if goal_in.subject_id and goal_in.subject_id != goal.subject_id:
            subject = subject_repository.get_by_id(db, subject_id=goal_in.subject_id, user_id=user_id)
            if not subject:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Subject not found or access denied.",
                )
        return goal_repository.update(db, db_goal=goal, goal_in=goal_in)

    def delete_goal(self, db: Session, goal_id: str, user_id: str) -> None:
        goal = self.get_user_goal_by_id(db, goal_id=goal_id, user_id=user_id)
        goal_repository.delete(db, db_goal=goal)

    def toggle_milestone(
        self, db: Session, goal_id: str, milestone_id: str, user_id: str
    ) -> GoalMilestone:
        goal = self.get_user_goal_by_id(db, goal_id=goal_id, user_id=user_id)
        milestone = goal_repository.toggle_milestone(
            db, milestone_id=milestone_id, goal_id=goal.id
        )
        if not milestone:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Milestone not found.",
            )
        return milestone


goal_service = GoalService()
