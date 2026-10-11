import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.api.dependencies import require_password_change_complete
from app.core.security import hash_password
from app.db.base import Base
from app.db.dependencies import get_db
from app.main import app
from app.models.user import User, UserRole


@pytest.fixture
def api():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False},
                           poolclass=StaticPool)
    Base.metadata.create_all(engine)
    with Session(engine) as session:
        user = User(full_name="Test Şef", username="sef",
                    password_hash=hash_password("Gecici-Parola-2026"),
                    role=UserRole.chief, is_active=True, must_change_password=True,
                    permissions=["viewVehicleFleet", "viewAllTechnicalWork"])
        session.add(user)
        session.commit()

        def override_db():
            yield session

        app.dependency_overrides[get_db] = override_db
        with TestClient(app) as client:
            yield client, session, user
        app.dependency_overrides.clear()
    engine.dispose()


def login(client):
    return client.post("/api/v1/auth/login", json={
        "username": "sef", "password": "Gecici-Parola-2026"})


def test_login_me_change_password_contract(api):
    client, session, user = api
    response = login(client)
    assert response.status_code == 200
    body = response.json()
    assert body["user"]["permissions"] == ["viewVehicleFleet", "viewAllTechnicalWork"]
    assert body["user"]["must_change_password"] is True
    assert "password_hash" not in body["user"]
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    assert client.get("/api/v1/auth/me", headers=headers).json()["id"] == str(user.id)
    changed = client.post("/api/v1/auth/change-password", headers=headers, json={
        "current_password": "Gecici-Parola-2026", "new_password": "Yeni-Guvenli-Parola-2026"})
    assert changed.status_code == 200
    assert client.get("/api/v1/auth/me", headers=headers).json()["must_change_password"] is False
    assert login(client).status_code == 401


def test_role_does_not_create_runtime_permissions(api):
    client, session, user = api
    user.permissions = []
    session.commit()
    assert login(client).json()["user"]["permissions"] == []


def test_me_rechecks_activity_and_permissions(api):
    client, session, user = api
    token = login(client).json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    user.permissions = []
    session.commit()
    assert client.get("/api/v1/auth/me", headers=headers).json()["permissions"] == []
    user.is_active = False
    session.commit()
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 403
    assert login(client).status_code == 401


def test_invalid_token_and_password_errors_are_safe(api):
    client, _, _ = api
    assert client.get("/api/v1/auth/me").status_code == 401
    assert client.get("/api/v1/auth/me", headers={"Authorization": "Bearer invalid"}).status_code == 401
    headers = {"Authorization": f"Bearer {login(client).json()['access_token']}"}
    result = client.post("/api/v1/auth/change-password", headers=headers, json={
        "current_password": "wrong", "new_password": "Yeni-Guvenli-Parola-2026"})
    assert result.status_code == 400


def test_required_password_dependency_enforced(api):
    client, session, user = api
    # No production business endpoint is added just to test this boundary.
    from fastapi import HTTPException
    with pytest.raises(HTTPException) as error:
        require_password_change_complete(user)
    assert error.value.status_code == 403
    user.must_change_password = False
    assert require_password_change_complete(user) is user
