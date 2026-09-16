from typing import Sequence
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.models.study_session import StudySession
from app.schemas.study_session import StudySessionCreate


class StudySessionRepository:
    def get_by_id(
        self, db: Session, session_id: str, user_id: str | None = None
    ) -> StudySession | None:
        statement = select(StudySession).where(StudySession.id == session_id)
        if user_id:
            statement = statement.where(StudySession.user_id == user_id)
        return db.scalars(statement).first()

    def get_all_by_user(
        self,
        db: Session,
        user_id: str,
        subject_id: str | None = None,
        limit: int = 50,
    ) -> Sequence[StudySession]:
        statement = select(StudySession).where(StudySession.user_id == user_id)
        if subject_id:
            statement = statement.where(StudySession.subject_id == subject_id)
        statement = statement.order_by(StudySession.started_at.desc()).limit(limit)
        return db.scalars(statement).all()

    def create(self, db: Session, user_id: str, session_in: StudySessionCreate) -> StudySession:
        db_session = StudySession(
            user_id=user_id,
            subject_id=session_in.subject_id,
            topic_id=session_in.topic_id,
            target_duration_minutes=session_in.target_duration_minutes,
            actual_duration_minutes=session_in.actual_duration_minutes,
            study_mode=session_in.study_mode,
            is_focus_monitoring_enabled=session_in.is_focus_monitoring_enabled,
            focus_score=session_in.focus_score,
            distractions_count=session_in.distractions_count,
            reflection=session_in.reflection,
            started_at=session_in.started_at,
            ended_at=session_in.ended_at,
        )
        db.add(db_session)
        db.commit()
        db.refresh(db_session)
        return db_session


study_session_repository = StudySessionRepository()
