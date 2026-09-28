import uuid
from datetime import datetime
from typing import List, Optional, TYPE_CHECKING
from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.db.base import Base

if TYPE_CHECKING:
    from app.models.user import User


class Conversation(Base):
    __tablename__ = "conversations"

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
        default="New Conversation",
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
    user: Mapped["User"] = relationship("User", back_populates="conversations")
    messages: Mapped[list["CoachMessage"]] = relationship(
        "CoachMessage",
        back_populates="conversation",
        cascade="all, delete-orphan",
        order_by="CoachMessage.created_at",
    )

    def __repr__(self) -> str:
        return f"<Conversation id={self.id} title={self.title}>"


class CoachMessage(Base):
    __tablename__ = "coach_messages"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    conversation_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey("conversations.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    role: Mapped[str] = mapped_column(
        String(20),  # "user", "assistant", or "system"
        default="user",
        nullable=False,
    )
    sender: Mapped[str] = mapped_column(
        String(20),  # "user" or "coach" (kept for backward compatibility)
        default="user",
        nullable=False,
    )
    message: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )
    mode: Mapped[str] = mapped_column(
        String(50),
        default="chat",
        nullable=False,
    )
    context_metadata: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="coach_messages")
    conversation: Mapped[Optional["Conversation"]] = relationship(
        "Conversation",
        back_populates="messages",
    )

    def __init__(self, **kwargs):
        if "role" in kwargs and "sender" not in kwargs:
            kwargs["sender"] = "coach" if kwargs["role"] in ("assistant", "system") else "user"
        elif "sender" in kwargs and "role" not in kwargs:
            kwargs["role"] = "assistant" if kwargs["sender"] in ("coach", "assistant") else "user"
        if "content" in kwargs and "message" not in kwargs:
            kwargs["message"] = kwargs.pop("content")
        super().__init__(**kwargs)

    @property
    def content(self) -> str:
        return self.message

    @content.setter
    def content(self, val: str) -> None:
        self.message = val

    def __repr__(self) -> str:
        return f"<CoachMessage id={self.id} role={self.role} conversation_id={self.conversation_id}>"


# Canonical alias
Message = CoachMessage


class CoachInsight(Base):
    __tablename__ = "coach_insights"

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
    category: Mapped[str] = mapped_column(
        String(100),
        default="Focus Pattern",
        nullable=False,
    )
    summary: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )
    action_recommendation: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )
    impact_metric: Mapped[str] = mapped_column(
        String(100),
        default="+15% Focus",
        nullable=False,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="coach_insights")

    def __repr__(self) -> str:
        return f"<CoachInsight id={self.id} title={self.title} category={self.category}>"
