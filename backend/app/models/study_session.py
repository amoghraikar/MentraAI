import uuid
from datetime import datetime
from typing import TYPE_CHECKING
from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.db.base import Base

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.subject import Subject
    from app.models.topic import Topic


class StudySession(Base):
    __tablename__ = "study_sessions"

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
    topic_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey("topics.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    target_duration_minutes: Mapped[int] = mapped_column(
        Integer,
        default=45,
        nullable=False,
    )
    actual_duration_minutes: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    study_mode: Mapped[str] = mapped_column(
        String(50),
        default="Focus Mode",
        nullable=False,
    )
    is_focus_monitoring_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )
    focus_score: Mapped[int] = mapped_column(
        Integer,
        default=100,
        nullable=False,
    )
    distractions_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    reflection: Mapped[str] = mapped_column(
        String(50),
        default="good",
        nullable=False,
    )
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    ended_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="study_sessions")
    subject: Mapped["Subject"] = relationship("Subject", back_populates="study_sessions")
    topic: Mapped["Topic | None"] = relationship("Topic", back_populates="study_sessions")

    def __repr__(self) -> str:
        return f"<StudySession id={self.id} subject_id={self.subject_id} focus_score={self.focus_score}>"
