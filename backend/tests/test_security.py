from app.core.security import hash_password, verify_password


def test_hash_password_uses_argon2_and_verifies_correct_password() -> None:
    plain_password = "GuvenliParola!42"

    hashed_password = hash_password(plain_password)

    assert hashed_password != plain_password
    assert hashed_password.startswith("$argon2")
    assert verify_password(plain_password, hashed_password)


def test_verify_password_rejects_wrong_password() -> None:
    hashed_password = hash_password("DogruParola!42")

    assert not verify_password("YanlisParola!42", hashed_password)


def test_same_password_produces_different_salted_hashes() -> None:
    plain_password = "AyniParola!42"

    first_hash = hash_password(plain_password)
    second_hash = hash_password(plain_password)

    assert first_hash != second_hash
    assert verify_password(plain_password, first_hash)
    assert verify_password(plain_password, second_hash)
