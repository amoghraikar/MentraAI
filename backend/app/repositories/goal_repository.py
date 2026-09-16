from typing import Sequence
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload
from app.models.goal import Goal, GoalMilestone
from app.schemas.goal import GoalCreate, GoalMilestoneCreate, GoalUpdate


class GoalRepository:
    def get_by_id(self, db: Session, goal_id: str, user_id: str | None = None) -> Goal | None:
        statement = (
            select(Goal)
            .options(selectinload(Goal.milestones))
            .where(Goal.id == goal_id)
        )
        if user_id:
            statement = statement.where(Goal.user_id == user_id)
        return db.scalars(statement).first()

    def get_all_by_user(self, db: Session, user_id: str) -> Sequence[Goal]:
        statement = (
            select(Goal)
            .options(selectinload(Goal.milestones))
            .where(Goal.user_id == user_id)
            .order_by(Goal.target_date.asc())
        )
        return db.scalars(statement).all()

    def create(self, db: Session, user_id: str, goal_in: GoalCreate) -> Goal:
        db_goal = Goal(
            user_id=user_id,
            subject_id=goal_in.subject_id,
            title=goal_in.title,
            target_date=goal_in.target_date,
            is_completed=goal_in.is_completed,
        )
        db.add(db_goal)
        db.flush()

        for m in goal_in.milestones:
            db_milestone = GoalMilestone(
                goal_id=db_goal.id,
                title=m.title,
                is_completed=m.is_completed,
            )
            db.add(db_milestone)

        db.commit()
        db.refresh(db_goal)
        return db_goal

    def update(self, db: Session, db_goal: Goal, goal_in: GoalUpdate) -> Goal:
        update_data = goal_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_goal, field, value)
        db.commit()
        db.refresh(db_goal)
        return db_goal

    def delete(self, db: Session, db_goal: Goal) -> None:
        db.delete(db_goal)
        db.commit()

    def toggle_milestone(self, db: Session, milestone_id: str, goal_id: str) -> GoalMilestone | None:
        statement = select(GoalMilestone).where(
            GoalMilestone.id == milestone_id,
            GoalMilestone.goal_id == goal_id,
        )
        milestone = db.scalars(statement).first()
        if milestone:
            milestone.is_completed = not milestone.is_completed
            db.commit()
            db.refresh(milestone)
        return milestone


goal_repository = GoalRepository()
