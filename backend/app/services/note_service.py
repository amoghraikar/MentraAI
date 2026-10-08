from typing import Sequence
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from app.models.note import Note
from app.models.subject import Subject
from app.repositories.note_repository import note_repository
from app.repositories.subject_repository import subject_repository
from app.schemas.note import NoteCreate, NoteUpdate
from app.schemas.subject import SubjectCreate


class NoteService:
    def _resolve_or_create_subject(
        self, db: Session, user_id: str, subject_identifier: str | None
    ) -> Subject:
        """Find an existing subject by ID, title, or code, or auto-create one so note operations never fail."""
        all_subjects = subject_repository.get_all_by_user(db, user_id=user_id)

        # 1. Match by exact ID
        if subject_identifier:
            for s in all_subjects:
                if s.id == subject_identifier:
                    return s

            # 2. Match by title or code (case-insensitive)
            clean_id = subject_identifier.strip().lower()
            for s in all_subjects:
                if s.title.lower() == clean_id or s.code.lower() == clean_id:
                    return s

        # 3. Known subject mappings from frontend
        title_map = {
            "sub_1": ("Data Analytics", "CS-401"),
            "sub_2": ("Software Engineering", "CS-402"),
            "sub_3": ("Web Programming", "CS-403"),
            "sub_gen": ("General Study Notes", "GEN-101"),
            "default": ("General Study Notes", "GEN-101"),
        }

        target_title, target_code = title_map.get(
            subject_identifier or "",
            (
                subject_identifier
                if subject_identifier and not subject_identifier.startswith("sub_")
                else "General Study Notes",
                "GEN-101",
            ),
        )

        # Check again if a subject with target_title already exists
        for s in all_subjects:
            if s.title.lower() == target_title.lower():
                return s

        # 4. If user already has any subject and identifier is generic, reuse their existing subject
        if all_subjects and (not subject_identifier or subject_identifier in ("sub_gen", "default", "")):
            return all_subjects[0]

        # 5. Create new subject so note operations succeed
        new_sub = subject_repository.create(
            db,
            user_id=user_id,
            subject_in=SubjectCreate(
                title=target_title,
                code=target_code,
                description=f"Auto-created subject for {target_title}",
            ),
        )
        return new_sub

    def _seed_default_notes(self, db: Session, user_id: str) -> Sequence[Note]:
        """Seed initial starter notes for a user who has no notes yet."""
        sub_da = self._resolve_or_create_subject(db, user_id, "Data Analytics")
        sub_se = self._resolve_or_create_subject(db, user_id, "Software Engineering")
        sub_web = self._resolve_or_create_subject(db, user_id, "Web Programming")

        notes_data = [
            NoteCreate(
                subject_id=sub_da.id,
                title="Correlation vs Causation & Regression Foundations",
                content="""# Correlation vs Causation & Regression Foundations

## Key Takeaways
- **Correlation** is bounded between -1.0 and +1.0. A value near 0 indicates no linear relationship.
- **Causation** requires controlled experimental validation or instrumental variables; correlation alone is never sufficient.
- **Ordinary Least Squares (OLS)** minimizes the sum of squared vertical residuals:
  `min sum((y_i - (beta_0 + beta_1 * x_i))^2)`

## Common Pitfalls
1. Confounding variables creating apparent correlations.
2. Homoscedasticity violation: when error variance increases with X, standard errors become biased.
3. Multicollinearity: check Variance Inflation Factor (VIF > 5 requires investigation).
""",
                tags=["Stats", "Formulas", "Exam Prep"],
            ),
            NoteCreate(
                subject_id=sub_se.id,
                title="Agile Scrum Ceremonies & Velocity Estimation",
                content="""# Agile Scrum Ceremonies & Velocity Estimation

## 4 Core Ceremonies
1. **Sprint Planning**: Commit to Sprint Goal based on team capacity and story estimates.
2. **Daily Standup (15m)**: What was completed yesterday, what is planned today, what blockers exist.
3. **Sprint Review / Demo**: Showcase working software increments to stakeholders.
4. **Sprint Retrospective**: Continuous improvement of team processes and team health.

## Story Points & Fibonnaci Scale
- 1, 2, 3, 5, 8, 13, 21.
- Points reflect relative complexity, risk, and cognitive effort, NOT raw elapsed clock hours.
""",
                tags=["Agile", "Methodology", "Scrum"],
            ),
            NoteCreate(
                subject_id=sub_web.id,
                title="CSS Modern Layout: Flexbox vs Grid System",
                content="""# CSS Modern Layout: Flexbox vs Grid System

## Rules of Thumb
- Use **Flexbox** for one-dimensional distribution (either row OR column).
- Use **CSS Grid** for two-dimensional grid layouts with explicit columns and rows.

```css
/* Clean Card Grid Pattern */
.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 16px;
}
```
""",
                tags=["CSS", "Layouts", "Web Dev"],
            ),
        ]
        created = []
        for n_in in notes_data:
            created.append(note_repository.create(db, user_id=user_id, note_in=n_in))
        return created

    def get_user_notes(
        self, db: Session, user_id: str, subject_id: str | None = None
    ) -> Sequence[Note]:
        notes = note_repository.get_all_by_user(db, user_id=user_id, subject_id=subject_id)
        if not notes and subject_id is None:
            notes = self._seed_default_notes(db, user_id=user_id)
        return notes

    def get_user_note_by_id(self, db: Session, note_id: str, user_id: str) -> Note:
        note = note_repository.get_by_id(db, note_id=note_id, user_id=user_id)
        if not note:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Note not found.",
            )
        return note

    def create_note(self, db: Session, user_id: str, note_in: NoteCreate) -> Note:
        subject = self._resolve_or_create_subject(db, user_id=user_id, subject_identifier=note_in.subject_id)
        note_in.subject_id = subject.id
        return note_repository.create(db, user_id=user_id, note_in=note_in)

    def update_note(
        self, db: Session, note_id: str, user_id: str, note_in: NoteUpdate
    ) -> Note:
        note = note_repository.get_by_id(db, note_id=note_id, user_id=user_id)
        if not note:
            # Upsert fallback: if note_id was a mock ID or local client ID, save to DB so user edits are never lost
            subject = self._resolve_or_create_subject(db, user_id=user_id, subject_identifier=note_in.subject_id)
            title = note_in.title.strip() if note_in.title and note_in.title.strip() else "Untitled Note"
            content = note_in.content or ""
            tags = note_in.tags or []
            create_in = NoteCreate(
                subject_id=subject.id,
                title=title,
                content=content,
                tags=tags,
            )
            return note_repository.create(db, user_id=user_id, note_in=create_in)

        if note_in.subject_id and note_in.subject_id != note.subject_id:
            subject = self._resolve_or_create_subject(db, user_id=user_id, subject_identifier=note_in.subject_id)
            note_in.subject_id = subject.id

        return note_repository.update(db, db_note=note, note_in=note_in)

    def delete_note(self, db: Session, note_id: str, user_id: str) -> None:
        note = self.get_user_note_by_id(db, note_id=note_id, user_id=user_id)
        note_repository.delete(db, db_note=note)


note_service = NoteService()

