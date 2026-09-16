from typing import List, Sequence
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload
from app.models.subject import Subject
from app.schemas.subject import SubjectCreate, SubjectUpdate


class SubjectRepository:
    def get_by_id(self, db: Session, subject_id: str, user_id: str | None = None) -> Subject | None:
        statement = (
            select(Subject)
            .options(selectinload(Subject.topics))
            .where(Subject.id == subject_id)
        )
        if user_id:
            statement = statement.where(Subject.user_id == user_id)
        return db.scalars(statement).first()

    def get_all_by_user(self, db: Session, user_id: str) -> Sequence[Subject]:
        statement = (
            select(Subject)
            .options(selectinload(Subject.topics))
            .where(Subject.user_id == user_id)
            .order_by(Subject.created_at.desc())
        )
        return db.scalars(statement).all()

    def create(self, db: Session, user_id: str, subject_in: SubjectCreate) -> Subject:
        db_subject = Subject(
            user_id=user_id,
            title=subject_in.title,
            code=subject_in.code,
            description=subject_in.description,
            color_hex=subject_in.color_hex,
            total_hours=subject_in.total_hours,
            target_hours=subject_in.target_hours,
        )
        db.add(db_subject)
        db.commit()
        db.refresh(db_subject)
        return db_subject

    def update(self, db: Session, db_subject: Subject, subject_in: SubjectUpdate) -> Subject:
        update_data = subject_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_subject, field, value)
        db.commit()
        db.refresh(db_subject)
        return db_subject

    def delete(self, db: Session, db_subject: Subject) -> None:
        db.delete(db_subject)
        db.commit()


subject_repository = SubjectRepository()
