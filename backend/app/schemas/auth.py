from pydantic import BaseModel, EmailStr, Field
from app.schemas.user import UserResponse, BCRYPT_MAX_PASSWORD_BYTES


class LoginRequest(BaseModel):
    email: EmailStr
    # No strength rules here (never leak policy on login), but bound the input
    # so oversized payloads are rejected instead of being fed to bcrypt.
    password: str = Field(
        ...,
        min_length=1,
        max_length=BCRYPT_MAX_PASSWORD_BYTES,
        description="Account password.",
    )


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class TokenPayload(BaseModel):
    sub: str | None = None
    exp: int | None = None
