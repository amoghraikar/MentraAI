from typing import Sequence
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.models.note import Note
from app.schemas.note import NoteCreate, NoteUpdate


class NoteRepository:
    def get_by_id(self, db: Session, note_id: str, user_id: str | None = None) -> Note | None:
        statement = select(Note).where(Note.id == note_id)
        if user_id:
            statement = statement.where(Note.user_id == user_id)
        return db.scalars(statement).first()

    def get_all_by_user(
        self, db: Session, user_id: str, subject_id: str | None = None
    ) -> Sequence[Note]:
        statement = select(Note).where(Note.user_id == user_id)
        if subject_id:
            statement = statement.where(Note.subject_id == subject_id)
        statement = statement.order_by(Note.updated_at.desc())
        return db.scalars(statement).all()

    def create(self, db: Session, user_id: str, note_in: NoteCreate) -> Note:
        db_note = Note(
            user_id=user_id,
            subject_id=note_in.subject_id,
            topic_id=note_in.topic_id,
            title=note_in.title,
            content=note_in.content,
            tags=note_in.tags,
        )
        db.add(db_note)
        db.commit()
        db.refresh(db_note)
        return db_note

    def update(self, db: Session, db_note: Note, note_in: NoteUpdate) -> Note:
        update_data = note_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_note, field, value)
        db.commit()
        db.refresh(db_note)
        return db_note

    def delete(self, db: Session, db_note: Note) -> None:
        db.delete(db_note)
        db.commit()


note_repository = NoteRepository()
