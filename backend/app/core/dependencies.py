import logging
import secrets
from typing import Generator
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
import jwt
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from app.core.security import decode_access_token, get_password_hash
from app.db.session import SessionLocal
from app.models.user import User
from app.repositories.user_repository import user_repository

logger = logging.getLogger("mentra.auth")

oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/api/v1/auth/login",
    auto_error=True,
)

# Internal account that owns AI chat history when nobody is signed in (guest / offline use).
LOCAL_GUEST_EMAIL = "guest@mentra.local"


def get_or_create_local_guest(db: Session) -> User:
    """Return the internal guest account used for local-only AI access.

    The account exists only so chat history has a valid owner while nobody is
    signed in. Its password is a random value that is never disclosed, so it
    cannot be used to sign in through /auth/login.
    """
    guest = user_repository.get_by_email(db, email=LOCAL_GUEST_EMAIL)
    if guest:
        return guest

    guest = User(
        email=LOCAL_GUEST_EMAIL,
        full_name="Mentra Guest",
        hashed_password=get_password_hash(secrets.token_urlsafe(48)),
        is_active=True,
    )
    db.add(guest)
    try:
        db.commit()
    except IntegrityError:
        # A concurrent request created the guest first.
        db.rollback()
        guest = user_repository.get_by_email(db, email=LOCAL_GUEST_EMAIL)
        if guest is None:
            raise
        return guest
    db.refresh(guest)
    return guest


def get_db() -> Generator[Session, None, None]:
    """Provide a database session for request lifecycle."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user(
    db: Session = Depends(get_db),
    token: str = Depends(oauth2_scheme),
) -> User:
    """Validate bearer token and return the current authenticated user."""
    if token == "offline-demo-jwt-token":
        guest = get_or_create_local_guest(db)
        if guest.is_active:
            return guest

    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_access_token(token)
        user_id: str | None = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.PyJWTError:
        raise credentials_exception

    user = user_repository.get_by_id(db, user_id=user_id)
    if user is None:
        raise credentials_exception
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Inactive user account.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return user


oauth2_scheme_optional = OAuth2PasswordBearer(
    tokenUrl="/api/v1/auth/login",
    auto_error=False,
)


def get_current_user_or_local(
    db: Session = Depends(get_db),
    token: str | None = Depends(oauth2_scheme_optional),
) -> User:
    """Validate bearer token or return the local student user for local AI inference."""
    if token:
        try:
            if token == "offline-demo-jwt-token":
                return get_or_create_local_guest(db)
            payload = decode_access_token(token)
            user_id: str | None = payload.get("sub")
            if user_id:
                user = user_repository.get_by_id(db, user_id=user_id)
                if user and user.is_active:
                    return user
        except Exception:
            pass

    # Guest account for offline / local-only AI use
    return get_or_create_local_guest(db)
