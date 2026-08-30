from datetime import datetime, timedelta, timezone

import jwt
from pwdlib import PasswordHash

from app.core.config import get_settings


ALGORITHM = "HS256"
MIN_PASSWORD_LENGTH = 12

_password_hash = PasswordHash.recommended()


class PasswordPolicyError(ValueError):
    """Raised when a new password does not satisfy the password policy."""


class InvalidTokenError(ValueError):
    """Raised when an access token cannot be trusted."""


def validate_new_password(password: str) -> None:
    if len(password) < MIN_PASSWORD_LENGTH:
        raise PasswordPolicyError(
            f"Parola en az {MIN_PASSWORD_LENGTH} karakter olmalıdır."
        )


def hash_password(plain_password: str) -> str:
    return _password_hash.hash(plain_password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return _password_hash.verify(plain_password, hashed_password)


def create_access_token(subject: str) -> tuple[str, int]:
    settings = get_settings()
    expires_in_seconds = settings.access_token_expire_minutes * 60
    now = datetime.now(timezone.utc)
    payload = {
        "sub": subject,
        "type": "access",
        "iat": now,
        "exp": now + timedelta(seconds=expires_in_seconds),
    }
    token = jwt.encode(
        payload,
        settings.secret_key.get_secret_value(),
        algorithm=ALGORITHM,
    )
    return token, expires_in_seconds


def decode_access_token(token: str) -> str:
    settings = get_settings()
    try:
        payload = jwt.decode(
            token,
            settings.secret_key.get_secret_value(),
            algorithms=[ALGORITHM],
        )
    except jwt.InvalidTokenError as exc:
        raise InvalidTokenError("Geçersiz veya süresi dolmuş oturum.") from exc

    subject = payload.get("sub")
    if payload.get("type") != "access" or not isinstance(subject, str):
        raise InvalidTokenError("Geçersiz oturum içeriği.")

    return subject
