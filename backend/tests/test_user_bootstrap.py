from unittest.mock import MagicMock

import pytest

from app.core.security import verify_password
from app.models.user import UserRole
from app.services.user_bootstrap import BootstrapError, create_initial_chief


def test_create_initial_chief_hashes_password_and_sets_safe_defaults() -> None:
    session = MagicMock()
    session.scalar.return_value = None

    user = create_initial_chief(
        session,
        full_name="  Ahmet Dulkadir  ",
        username="  SEF  ",
        email="  SEF@EXAMPLE.COM  ",
        password="Guvenli-Gecici-2026",
    )

    assert user.full_name == "Ahmet Dulkadir"
    assert user.username == "sef"
    assert user.email == "sef@example.com"
    assert user.role is UserRole.chief
    assert user.is_active is True
    assert user.must_change_password is True
    assert user.password_hash != "Guvenli-Gecici-2026"
    assert verify_password("Guvenli-Gecici-2026", user.password_hash)
    session.add.assert_called_once_with(user)
    session.commit.assert_called_once()
    session.refresh.assert_called_once_with(user)


def test_create_initial_chief_refuses_non_empty_users_table() -> None:
    session = MagicMock()
    session.scalar.return_value = object()

    with pytest.raises(BootstrapError, match="daha önce oluşturulmuş"):
        create_initial_chief(
            session,
            full_name="Ahmet Dulkadir",
            username="sef",
            email=None,
            password="Guvenli-Gecici-2026",
        )

    session.add.assert_not_called()
    session.commit.assert_not_called()


@pytest.mark.parametrize(
    ("field_overrides", "expected_message"),
    [
        ({"full_name": " "}, "Ad soyad"),
        ({"username": "iki kelime"}, "boşluk"),
        ({"password": "kisa"}, "en az 12"),
    ],
)
def test_create_initial_chief_validates_input(
    field_overrides: dict[str, str],
    expected_message: str,
) -> None:
    session = MagicMock()
    session.scalar.return_value = None
    fields = {
        "full_name": "Ahmet Dulkadir",
        "username": "sef",
        "email": None,
        "password": "Guvenli-Gecici-2026",
    }
    fields.update(field_overrides)

    with pytest.raises(BootstrapError, match=expected_message):
        create_initial_chief(session, **fields)

    session.add.assert_not_called()
    session.commit.assert_not_called()
