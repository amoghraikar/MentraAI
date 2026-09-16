from typing import Sequence
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from app.models.subject import Subject
from app.repositories.subject_repository import subject_repository
from app.schemas.subject import SubjectCreate, SubjectUpdate


class SubjectService:
    def get_user_subjects(self, db: Session, user_id: str) -> Sequence[Subject]:
        return subject_repository.get_all_by_user(db, user_id=user_id)

    def get_user_subject_by_id(self, db: Session, subject_id: str, user_id: str) -> Subject:
        subject = subject_repository.get_by_id(db, subject_id=subject_id, user_id=user_id)
        if not subject:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subject not found.",
            )
        return subject

    def create_subject(self, db: Session, user_id: str, subject_in: SubjectCreate) -> Subject:
        return subject_repository.create(db, user_id=user_id, subject_in=subject_in)

    def update_subject(
        self, db: Session, subject_id: str, user_id: str, subject_in: SubjectUpdate
    ) -> Subject:
        subject = self.get_user_subject_by_id(db, subject_id=subject_id, user_id=user_id)
        return subject_repository.update(db, db_subject=subject, subject_in=subject_in)

    def delete_subject(self, db: Session, subject_id: str, user_id: str) -> None:
        subject = self.get_user_subject_by_id(db, subject_id=subject_id, user_id=user_id)
        subject_repository.delete(db, db_subject=subject)


subject_service = SubjectService()
