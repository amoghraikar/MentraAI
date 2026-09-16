import uuid
from datetime import datetime
from typing import List, TYPE_CHECKING
from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.db.base import Base

if TYPE_CHECKING:
    from app.models.subject import Subject
    from app.models.note import Note
    from app.models.study_session import StudySession


class Topic(Base):
    __tablename__ = "topics"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
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
    description: Mapped[str] = mapped_column(
        Text,
        default="",
        nullable=False,
    )
    progress: Mapped[float] = mapped_column(
        Float,
        default=0.0,
        nullable=False,
    )
    total_minutes: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    key_concepts: Mapped[list] = mapped_column(
        JSON,
        default=list,
        nullable=False,
    )
    notes_snippet: Mapped[str] = mapped_column(
        Text,
        default="",
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
    subject: Mapped["Subject"] = relationship("Subject", back_populates="topics")
    notes: Mapped[List["Note"]] = relationship(
        "Note",
        back_populates="topic",
        cascade="all, delete-orphan",
    )
    study_sessions: Mapped[List["StudySession"]] = relationship(
        "StudySession",
        back_populates="topic",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<Topic id={self.id} title={self.title} subject_id={self.subject_id}>"
