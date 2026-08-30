from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.security import (
    PasswordPolicyError,
    hash_password,
    validate_new_password,
    verify_password,
)
from app.models.user import User


class PasswordChangeError(ValueError):
    """Raised when a password change request cannot be completed."""


# A missing username still performs an Argon2 verification. This makes account
# discovery through response timing harder.
_DUMMY_PASSWORD_HASH = hash_password("not-a-real-user-password")


def authenticate_user(
    session: Session,
    *,
    username: str,
    password: str,
) -> User | None:
    normalized_username = username.strip().lower()
    user = session.scalar(
        select(User).where(User.username == normalized_username)
    )
    password_hash = user.password_hash if user else _DUMMY_PASSWORD_HASH
    password_matches = verify_password(password, password_hash)

    if user is None or not password_matches or not user.is_active:
        return None
    return user


def change_user_password(
    session: Session,
    *,
    user: User,
    current_password: str,
    new_password: str,
) -> None:
    if not verify_password(current_password, user.password_hash):
        raise PasswordChangeError("Mevcut parola doğru değil.")
    if verify_password(new_password, user.password_hash):
        raise PasswordChangeError("Yeni parola mevcut paroladan farklı olmalıdır.")

    try:
        validate_new_password(new_password)
    except PasswordPolicyError as exc:
        raise PasswordChangeError(str(exc)) from exc

    user.password_hash = hash_password(new_password)
    user.must_change_password = False

    try:
        session.commit()
    except IntegrityError as exc:
        session.rollback()
        raise PasswordChangeError("Parola değişikliği kaydedilemedi.") from exc

    session.refresh(user)
