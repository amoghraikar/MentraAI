from typing import Sequence
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from app.models.study_session import StudySession
from app.repositories.study_session_repository import study_session_repository
from app.repositories.subject_repository import subject_repository
from app.repositories.topic_repository import topic_repository
from app.schemas.study_session import StudySessionCreate


class StudySessionService:
    def get_user_sessions(
        self,
        db: Session,
        user_id: str,
        subject_id: str | None = None,
        limit: int = 50,
    ) -> Sequence[StudySession]:
        return study_session_repository.get_all_by_user(
            db, user_id=user_id, subject_id=subject_id, limit=limit
        )

    def get_user_session_by_id(
        self, db: Session, session_id: str, user_id: str
    ) -> StudySession:
        session_obj = study_session_repository.get_by_id(
            db, session_id=session_id, user_id=user_id
        )
        if not session_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Study session not found.",
            )
        return session_obj

    def record_session(
        self, db: Session, user_id: str, session_in: StudySessionCreate
    ) -> StudySession:
        subject = subject_repository.get_by_id(
            db, subject_id=session_in.subject_id, user_id=user_id
        )
        if not subject:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subject not found or access denied.",
            )

        if session_in.topic_id:
            topic = topic_repository.get_by_id(db, topic_id=session_in.topic_id)
            if not topic or topic.subject_id != subject.id:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Topic not found or does not belong to the selected subject.",
                )
            # Update topic minutes
            topic.total_minutes += session_in.actual_duration_minutes
            db.add(topic)

        # Update subject total hours
        subject.total_hours += round(session_in.actual_duration_minutes / 60.0, 2)
        db.add(subject)

        return study_session_repository.create(db, user_id=user_id, session_in=session_in)


study_session_service = StudySessionService()
