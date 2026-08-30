from unittest.mock import MagicMock
from uuid import uuid4

import pytest

from app.core.security import (
    InvalidTokenError,
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)
from app.models.user import User, UserRole
from app.services.auth import (
    PasswordChangeError,
    authenticate_user,
    change_user_password,
)


def _user(*, active: bool = True) -> User:
    return User(
        id=uuid4(),
        full_name="Ahmet Dulkadir",
        username="sef",
        email=None,
        password_hash=hash_password("Guvenli-Gecici-2026"),
        role=UserRole.chief,
        is_active=active,
        must_change_password=True,
    )


def test_access_token_round_trip() -> None:
    subject = str(uuid4())

    token, expires_in = create_access_token(subject)

    assert expires_in == 1800
    assert decode_access_token(token) == subject


def test_tampered_access_token_is_rejected() -> None:
    token, _ = create_access_token(str(uuid4()))

    with pytest.raises(InvalidTokenError):
        decode_access_token(f"{token}tampered")


def test_authenticate_user_accepts_correct_credentials() -> None:
    session = MagicMock()
    user = _user()
    session.scalar.return_value = user

    authenticated_user = authenticate_user(
        session,
        username="  SEF ",
        password="Guvenli-Gecici-2026",
    )

    assert authenticated_user is user


@pytest.mark.parametrize(
    ("database_user", "password"),
    [
        (None, "Guvenli-Gecici-2026"),
        (_user(), "Yanlis-Parola-2026"),
        (_user(active=False), "Guvenli-Gecici-2026"),
    ],
)
def test_authenticate_user_rejects_invalid_login(
    database_user: User | None,
    password: str,
) -> None:
    session = MagicMock()
    session.scalar.return_value = database_user

    assert (
        authenticate_user(session, username="sef", password=password) is None
    )


def test_change_password_replaces_hash_and_clears_requirement() -> None:
    session = MagicMock()
    user = _user()

    change_user_password(
        session,
        user=user,
        current_password="Guvenli-Gecici-2026",
        new_password="Yeni-Guvenli-Parola-2026",
    )

    assert verify_password("Yeni-Guvenli-Parola-2026", user.password_hash)
    assert not verify_password("Guvenli-Gecici-2026", user.password_hash)
    assert user.must_change_password is False
    session.commit.assert_called_once()
    session.refresh.assert_called_once_with(user)


def test_change_password_rejects_wrong_current_password() -> None:
    session = MagicMock()
    user = _user()

    with pytest.raises(PasswordChangeError, match="Mevcut parola"):
        change_user_password(
            session,
            user=user,
            current_password="Yanlis-Parola-2026",
            new_password="Yeni-Guvenli-Parola-2026",
        )

    session.commit.assert_not_called()
