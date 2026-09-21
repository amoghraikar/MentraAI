from datetime import datetime

from pydantic import (
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    field_validator,
    model_validator,
)

# bcrypt only hashes the first 72 bytes of a password. Anything longer is
# silently truncated, which would let two different long passwords unlock the
# same account. We reject over-long passwords instead of storing a truncated key.
BCRYPT_MAX_PASSWORD_BYTES = 72
MIN_PASSWORD_LENGTH = 10

# Domains that can never receive mail. Accounts registered against them can
# never be verified or recovered, so they are not allowed into the database.
_BLOCKED_EMAIL_DOMAINS = frozenset(
    {
        "example.com",
        "example.org",
        "example.net",
        "test.com",
        "test",
        "localhost",
        "invalid",
        "local",
        "mentra.local",
    }
)

# Throwaway / disposable mailbox providers.
_DISPOSABLE_EMAIL_DOMAINS = frozenset(
    {
        "mailinator.com",
        "guerrillamail.com",
        "10minutemail.com",
        "tempmail.com",
        "tempmail.net",
        "throwawaymail.com",
        "yopmail.com",
        "trashmail.com",
        "sharklasers.com",
        "getnada.com",
        "dispostable.com",
        "fakeinbox.com",
        "maildrop.cc",
        "temp-mail.org",
        "mailnesia.com",
        "spam4.me",
        "grr.la",
    }
)

# Passwords that show up at the top of every breach list.
_WEAK_PASSWORDS = frozenset(
    {
        "password",
        "password1",
        "password12",
        "password123",
        "password1234",
        "passw0rd",
        "p@ssw0rd",
        "12345678",
        "123456789",
        "1234567890",
        "qwerty",
        "qwerty123",
        "qwertyuiop",
        "letmein",
        "welcome",
        "welcome1",
        "admin",
        "admin123",
        "iloveyou",
        "monkey",
        "dragon",
        "abc12345",
        "football",
        "baseball",
        "sunshine",
        "princess",
        "login123",
        "changeme",
        "secret123",
        "mentra123",
    }
)


class UserBase(BaseModel):
    email: EmailStr
    full_name: str | None = None


class UserCreate(UserBase):
    password: str = Field(
        ...,
        min_length=MIN_PASSWORD_LENGTH,
        max_length=128,
        description=(
            "Password must be 10-72 bytes and contain at least one uppercase "
            "letter, one lowercase letter, one digit, and one special character."
        ),
    )

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        """Enforce a genuinely strong password before it is ever hashed."""
        if len(v.encode("utf-8")) > BCRYPT_MAX_PASSWORD_BYTES:
            raise ValueError(
                f"Password must be at most {BCRYPT_MAX_PASSWORD_BYTES} bytes long."
            )

        missing = []
        if not any(c.isupper() for c in v):
            missing.append("an uppercase letter")
        if not any(c.islower() for c in v):
            missing.append("a lowercase letter")
        if not any(c.isdigit() for c in v):
            missing.append("a digit")
        if not any(not c.isalnum() for c in v):
            missing.append("a special character")
        if missing:
            raise ValueError(f"Password must contain {', '.join(missing)}.")

        normalized = v.strip().lower()
        if normalized in _WEAK_PASSWORDS or normalized.rstrip("!@#$%^&*") in _WEAK_PASSWORDS:
            raise ValueError(
                "Password is too common and easily guessed. Choose a less predictable password."
            )
        if len(set(v)) < 4:
            raise ValueError("Password is too repetitive. Use a wider mix of characters.")

        return v

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        """Normalize and reject addresses that cannot belong to a real mailbox."""
        email = v.strip().lower()
        local_part, sep, domain = email.partition("@")
        if not sep or not local_part or not domain:
            raise ValueError("Enter a valid email address.")
        if domain in _BLOCKED_EMAIL_DOMAINS:
            raise ValueError(
                f"'{domain}' is a reserved domain that cannot receive email. "
                "Use a real, working email address."
            )
        if domain in _DISPOSABLE_EMAIL_DOMAINS:
            raise ValueError(
                "Disposable email addresses are not supported. Use a permanent address."
            )
        return email

    @model_validator(mode="after")
    def password_not_derived_from_email(self) -> "UserCreate":
        """A password must not be built out of the account's own email address."""
        local_part = self.email.split("@", 1)[0].lower()
        if len(local_part) >= 4 and local_part in self.password.lower():
            raise ValueError("Password must not contain your email address.")
        return self


class UserResponse(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    is_active: bool
    created_at: datetime
