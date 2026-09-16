import uuid
from datetime import datetime
from typing import List, TYPE_CHECKING
from sqlalchemy import DateTime, Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.db.base import Base

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.topic import Topic
    from app.models.note import Note
    from app.models.goal import Goal
    from app.models.study_session import StudySession


class Subject(Base):
    __tablename__ = "subjects"

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
    title: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    code: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )
    description: Mapped[str] = mapped_column(
        Text,
        default="",
        nullable=False,
    )
    color_hex: Mapped[str] = mapped_column(
        String(20),
        default="#4F46E5",
        nullable=False,
    )
    total_hours: Mapped[float] = mapped_column(
        Float,
        default=0.0,
        nullable=False,
    )
    target_hours: Mapped[float] = mapped_column(
        Float,
        default=20.0,
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
    user: Mapped["User"] = relationship("User", back_populates="subjects")
    topics: Mapped[List["Topic"]] = relationship(
        "Topic",
        back_populates="subject",
        cascade="all, delete-orphan",
    )
    notes: Mapped[List["Note"]] = relationship(
        "Note",
        back_populates="subject",
        cascade="all, delete-orphan",
    )
    goals: Mapped[List["Goal"]] = relationship(
        "Goal",
        back_populates="subject",
        cascade="all, delete-orphan",
    )
    study_sessions: Mapped[List["StudySession"]] = relationship(
        "StudySession",
        back_populates="subject",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<Subject id={self.id} title={self.title} code={self.code}>"
