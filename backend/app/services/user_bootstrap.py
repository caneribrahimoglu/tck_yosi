from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.security import (
    PasswordPolicyError,
    hash_password,
    validate_new_password,
)
from app.models.user import User, UserRole


class BootstrapError(ValueError):
    """Raised when the one-time initial account cannot be created."""


def _normalize_and_validate(
    *,
    full_name: str,
    username: str,
    email: str | None,
    password: str,
) -> tuple[str, str, str | None]:
    normalized_full_name = full_name.strip()
    normalized_username = username.strip().lower()
    normalized_email = email.strip().lower() if email else None

    if not normalized_full_name:
        raise BootstrapError("Ad soyad boş bırakılamaz.")
    if len(normalized_full_name) > 120:
        raise BootstrapError("Ad soyad en fazla 120 karakter olabilir.")
    if not normalized_username:
        raise BootstrapError("Kullanıcı adı boş bırakılamaz.")
    if len(normalized_username) > 50:
        raise BootstrapError("Kullanıcı adı en fazla 50 karakter olabilir.")
    if any(character.isspace() for character in normalized_username):
        raise BootstrapError("Kullanıcı adı boşluk içeremez.")
    if normalized_email and len(normalized_email) > 255:
        raise BootstrapError("E-posta en fazla 255 karakter olabilir.")

    try:
        validate_new_password(password)
    except PasswordPolicyError as exc:
        raise BootstrapError(str(exc)) from exc

    return normalized_full_name, normalized_username, normalized_email


def create_initial_chief(
    session: Session,
    *,
    full_name: str,
    username: str,
    email: str | None,
    password: str,
) -> User:
    """Create the only account allowed while the users table is empty."""
    existing_user_id = session.scalar(select(User.id).limit(1))
    if existing_user_id is not None:
        raise BootstrapError(
            "İlk hesap daha önce oluşturulmuş. Bu komut yalnızca boş sistemde çalışır."
        )

    normalized_full_name, normalized_username, normalized_email = (
        _normalize_and_validate(
            full_name=full_name,
            username=username,
            email=email,
            password=password,
        )
    )

    user = User(
        full_name=normalized_full_name,
        username=normalized_username,
        email=normalized_email,
        password_hash=hash_password(password),
        role=UserRole.chief,
        is_active=True,
        must_change_password=True,
    )
    session.add(user)

    try:
        session.commit()
    except IntegrityError as exc:
        session.rollback()
        raise BootstrapError(
            "İlk hesap başka bir işlem tarafından oluşturulmuş olabilir."
        ) from exc

    session.refresh(user)
    return user
