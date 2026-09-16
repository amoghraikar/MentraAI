from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from app.core.dependencies import get_current_user, get_db
from app.models.user import User
from app.schemas.note import NoteCreate, NoteResponse, NoteUpdate
from app.services.note_service import note_service

router = APIRouter()


@router.get("", response_model=List[NoteResponse])
def get_notes(
    subject_id: Optional[str] = Query(None, description="Filter notes by subject"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve all notes belonging to the authenticated user."""
    return note_service.get_user_notes(
        db, user_id=current_user.id, subject_id=subject_id
    )


@router.post("", response_model=NoteResponse, status_code=status.HTTP_201_CREATED)
def create_note(
    note_in: NoteCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new note for the authenticated user."""
    return note_service.create_note(db, user_id=current_user.id, note_in=note_in)


@router.get("/{note_id}", response_model=NoteResponse)
def get_note(
    note_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve a specific note by ID."""
    return note_service.get_user_note_by_id(
        db, note_id=note_id, user_id=current_user.id
    )


@router.put("/{note_id}", response_model=NoteResponse)
def update_note(
    note_id: str,
    note_in: NoteUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update a note's title, content, or tags."""
    return note_service.update_note(
        db, note_id=note_id, user_id=current_user.id, note_in=note_in
    )


@router.delete("/{note_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_note(
    note_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a note."""
    note_service.delete_note(db, note_id=note_id, user_id=current_user.id)
