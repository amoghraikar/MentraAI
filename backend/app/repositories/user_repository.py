from sqlalchemy import select
from sqlalchemy.orm import Session
from app.models.user import User
from app.schemas.user import UserCreate


class UserRepository:
    def get_by_id(self, db: Session, user_id: str) -> User | None:
        statement = select(User).where(User.id == user_id)
        return db.scalars(statement).first()

    def get_by_email(self, db: Session, email: str) -> User | None:
        statement = select(User).where(User.email == email.lower())
        return db.scalars(statement).first()

    def create(self, db: Session, user_in: UserCreate, hashed_password: str) -> User:
        db_user = User(
            email=user_in.email.lower(),
            full_name=user_in.full_name,
            hashed_password=hashed_password,
            is_active=True,
        )
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        return db_user


user_repository = UserRepository()
