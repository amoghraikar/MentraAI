from typing import Sequence
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from app.models.note import Note
from app.repositories.note_repository import note_repository
from app.repositories.subject_repository import subject_repository
from app.schemas.note import NoteCreate, NoteUpdate


class NoteService:
    def get_user_notes(
        self, db: Session, user_id: str, subject_id: str | None = None
    ) -> Sequence[Note]:
        return note_repository.get_all_by_user(db, user_id=user_id, subject_id=subject_id)

    def get_user_note_by_id(self, db: Session, note_id: str, user_id: str) -> Note:
        note = note_repository.get_by_id(db, note_id=note_id, user_id=user_id)
        if not note:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Note not found.",
            )
        return note

    def create_note(self, db: Session, user_id: str, note_in: NoteCreate) -> Note:
        subject = subject_repository.get_by_id(db, subject_id=note_in.subject_id, user_id=user_id)
        if not subject:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subject not found or access denied.",
            )
        return note_repository.create(db, user_id=user_id, note_in=note_in)

    def update_note(
        self, db: Session, note_id: str, user_id: str, note_in: NoteUpdate
    ) -> Note:
        note = self.get_user_note_by_id(db, note_id=note_id, user_id=user_id)
        if note_in.subject_id and note_in.subject_id != note.subject_id:
            subject = subject_repository.get_by_id(db, subject_id=note_in.subject_id, user_id=user_id)
            if not subject:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Subject not found or access denied.",
                )
        return note_repository.update(db, db_note=note, note_in=note_in)

    def delete_note(self, db: Session, note_id: str, user_id: str) -> None:
        note = self.get_user_note_by_id(db, note_id=note_id, user_id=user_id)
        note_repository.delete(db, db_note=note)


note_service = NoteService()
