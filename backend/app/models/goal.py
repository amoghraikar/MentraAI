import uuid
from datetime import datetime
from typing import List, TYPE_CHECKING
from sqlalchemy import Boolean, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.db.base import Base

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.subject import Subject


class Goal(Base):
    __tablename__ = "goals"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    subject_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("subjects.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    target_date: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    is_completed: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="goals")
    subject: Mapped["Subject"] = relationship("Subject", back_populates="goals")
    milestones: Mapped[List["GoalMilestone"]] = relationship(
        "GoalMilestone",
        back_populates="goal",
        cascade="all, delete-orphan",
        order_by="GoalMilestone.created_at",
    )

    def __repr__(self) -> str:
        return f"<Goal id={self.id} title={self.title} subject_id={self.subject_id}>"


class GoalMilestone(Base):
    __tablename__ = "goal_milestones"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    goal_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("goals.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    is_completed: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    goal: Mapped["Goal"] = relationship("Goal", back_populates="milestones")

    def __repr__(self) -> str:
        return f"<GoalMilestone id={self.id} goal_id={self.goal_id} title={self.title}>"
