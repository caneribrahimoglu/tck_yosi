from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.security import create_access_token, hash_password, verify_password
from app.db.base import Base
from app.db.dependencies import get_db
from app.main import app
from app.models.permission import INITIAL_CHIEF_PERMISSIONS
from app.models.team import Team, TeamMembership
from app.models.user import User, UserRole


@pytest.fixture
def api():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as session:
        chief = User(full_name="Test Şef", username="sef", role=UserRole.chief,
                     password_hash=hash_password("Test-Parola-2026"), permissions=list(INITIAL_CHIEF_PERMISSIONS),
                     is_active=True, must_change_password=False)
        engineer = User(full_name="Test Mühendis", username="muhendis", role=UserRole.engineer,
                        password_hash=chief.password_hash, permissions=[], is_active=True, must_change_password=False)
        session.add_all([chief, engineer])
        session.commit()
        def override():
            yield session
        app.dependency_overrides[get_db] = override
        with TestClient(app) as client:
            def headers(user):
                token, _ = create_access_token(str(user.id))
                return {"Authorization": f"Bearer {token}"}
            yield client, session, chief, engineer, headers
        app.dependency_overrides.clear()
    engine.dispose()


def make_team(client, headers, name="Teknik Ekip"):
    response = client.post("/api/v1/teams", headers=headers, json={"name": name, "description": "Test"})
    assert response.status_code == 201
    return response.json()["id"]


def test_create_user_password_policy_unique_username_and_no_secret(api):
    client, session, chief, _, headers = api
    payload = {"full_name": "Yeni Kullanıcı", "username": "Yeni", "role": "engineer",
               "temporary_password": "Gecici-Parola-2026"}
    response = client.post("/api/v1/users", headers=headers(chief), json=payload)
    assert response.status_code == 201
    user = response.json()
    assert user["username"] == "yeni" and user["must_change_password"] is True
    assert user["permissions"] == []
    assert "password_hash" not in user and "temporary_password" not in user
    assert client.post("/api/v1/users", headers=headers(chief), json=payload).status_code == 409
    payload.update(username="short", temporary_password="123456")
    assert client.post("/api/v1/users", headers=headers(chief), json=payload).status_code == 422
    payload.update(username="admin2", temporary_password="Gecici-Parola-2026", role="chief")
    assert client.post("/api/v1/users", headers=headers(chief), json=payload).status_code == 403


@pytest.mark.parametrize("path,body", [
    ("users", {"full_name": "Test User", "username": "other", "role": "engineer", "temporary_password": "Gecici-Parola-2026"}),
    ("users/{user}/active", {"is_active": False}),
    ("users/{user}/permissions", {"permissions": []}),
    ("users/{user}/reset-password", {"temporary_password": "Gecici-Parola-2026"}),
    ("teams", {"name": "Yeni Ekip"}),
    ("teams/{team}/details", {"name": "Yeni Ad"}),
    ("teams/{team}/active", {"is_active": False}),
    ("teams/{team}/archive", {}), ("teams/{team}/restore", {}),
    ("teams/{team}/permissions", {"permissions": []}),
    ("teams/{team}/members", {"user_id": "{user}"}),
    ("teams/{team}/members/{user}/remove", {}),
])
def test_every_mutation_checks_persisted_direct_permission_before_lookup(api, path, body):
    client, session, chief, engineer, headers = api
    team_id = make_team(client, headers(chief))
    path = path.replace("{user}", str(engineer.id)).replace("{team}", team_id)
    body = {key: str(engineer.id) if value == "{user}" else value for key, value in body.items()}
    response = client.post(f"/api/v1/{path}", headers=headers(engineer), json=body)
    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "not_allowed"
    # Role alone cannot authorize, even with a previously issued token.
    token = headers(chief)
    chief.permissions = []
    session.commit()
    assert client.post(f"/api/v1/{path}", headers=token, json=body).status_code == 403


def test_self_and_other_chief_accounts_are_protected(api):
    client, session, chief, engineer, headers = api
    assert client.post(f"/api/v1/users/{chief.id}/active", headers=headers(chief), json={"is_active": False}).status_code == 403
    assert client.post(f"/api/v1/users/{chief.id}/permissions", headers=headers(chief), json={"permissions": []}).status_code == 403
    engineer.role = UserRole.chief
    session.commit()
    assert client.post(f"/api/v1/users/{engineer.id}/reset-password", headers=headers(chief),
                       json={"temporary_password": "Gecici-Parola-2026"}).status_code == 403


def test_direct_grants_subset_protected_and_active_password_reset(api):
    client, session, chief, engineer, headers = api
    endpoint = f"/api/v1/users/{engineer.id}"
    for permission in ["manageUsers", "manageTeamPermissions", "receiveVehicle"]:
        assert client.post(f"{endpoint}/permissions", headers=headers(chief), json={"permissions": [permission]}).status_code == 403
    assert client.post(f"{endpoint}/permissions", headers=headers(chief), json={"permissions": ["startTechnicalWork"]}).status_code == 200
    assert client.post(f"{endpoint}/reset-password", headers=headers(chief),
                       json={"temporary_password": "Yeni-Gecici-2026"}).status_code == 200
    session.refresh(engineer)
    assert engineer.must_change_password and verify_password("Yeni-Gecici-2026", engineer.password_hash)
    assert client.get("/api/v1/directory", headers=headers(engineer)).status_code == 403
    assert client.post(f"{endpoint}/active", headers=headers(chief), json={"is_active": False}).status_code == 200
    assert client.get("/api/v1/teams", headers=headers(engineer)).status_code == 403


def test_name_normalization_update_and_archived_conflict(api):
    client, _, chief, _, headers = api
    h = headers(chief)
    team_id = make_team(client, h, "Teknik Ekip")
    assert client.post("/api/v1/teams", headers=h, json={"name": "  TEKNİK EKİP  "}).status_code == 409
    assert client.post(f"/api/v1/teams/{team_id}/details", headers=h,
                       json={"name": "Teknik Ekip", "description": "Yeni"}).status_code == 200
    second = make_team(client, h, "İkinci Ekip")
    assert client.post(f"/api/v1/teams/{second}/details", headers=h, json={"name": "Teknik Ekip"}).status_code == 409
    client.post(f"/api/v1/teams/{team_id}/archive", headers=h, json={})
    conflict = client.post("/api/v1/teams", headers=h, json={"name": "teknik ekip"})
    assert conflict.json()["detail"] == {"code": "archived_team_name", "team_id": team_id, "team_name": "Teknik Ekip"}


def test_membership_many_teams_duplicate_remove_and_reactivate_same_id(api):
    client, session, chief, engineer, headers = api
    h = headers(chief)
    first, second = make_team(client, h), make_team(client, h, "İkinci Ekip")
    endpoint = f"/api/v1/teams/{first}/members"
    member = client.post(endpoint, headers=h, json={"user_id": str(engineer.id)}).json()
    assert client.post(endpoint, headers=h, json={"user_id": str(engineer.id)}).status_code == 409
    assert client.post(f"/api/v1/teams/{second}/members", headers=h, json={"user_id": str(engineer.id)}).status_code == 201
    client.post(f"{endpoint}/{engineer.id}/remove", headers=h, json={})
    readded = client.post(endpoint, headers=h, json={"user_id": str(engineer.id)}).json()
    assert readded["id"] == member["id"] and readded["is_active"]
    assert len(session.scalars(select(TeamMembership)).all()) == 2


@pytest.mark.parametrize("path,body", [
    ("details", {"name": "Yeni Ad"}), ("active", {"is_active": True}),
    ("permissions", {"permissions": []}), ("members", {"user_id": "{user}"}),
    ("members/{user}/remove", {}),
])
def test_archived_team_mutations_rejected(api, path, body):
    client, session, chief, engineer, headers = api
    h = headers(chief)
    team_id = make_team(client, h)
    client.post(f"/api/v1/teams/{team_id}/archive", headers=h, json={})
    body = {key: str(engineer.id) if value == "{user}" else value for key, value in body.items()}
    path = path.replace("{user}", str(engineer.id))
    response = client.post(f"/api/v1/teams/{team_id}/{path}", headers=h, json=body)
    assert response.status_code == 409 and response.json()["detail"]["code"] == "team_archived"


def test_archive_restore_preserves_members_permissions_and_returns_passive(api):
    client, _, chief, engineer, headers = api
    h = headers(chief)
    team_id = make_team(client, h)
    client.post(f"/api/v1/teams/{team_id}/permissions", headers=h, json={"permissions": ["startTechnicalWork"]})
    member = client.post(f"/api/v1/teams/{team_id}/members", headers=h, json={"user_id": str(engineer.id)}).json()
    assert client.post(f"/api/v1/teams/{team_id}/restore", headers=h, json={}).status_code == 409
    for _ in range(2):
        assert client.post(f"/api/v1/teams/{team_id}/archive", headers=h, json={}).status_code == 200
    restored = client.post(f"/api/v1/teams/{team_id}/restore", headers=h, json={}).json()
    assert restored["id"] == team_id and not restored["is_archived"] and not restored["is_active"]
    assert restored["permissions"] == ["startTechnicalWork"]
    assert client.get("/api/v1/teams/memberships", headers=h).json()[0]["id"] == member["id"]


@pytest.mark.parametrize("permission", ["manageUsers", "manageTeamPermissions", "viewAllTechnicalWork",
                                        "viewVehicleFleet", "reviewTechnicalWorkCompletion", "receiveVehicle"])
def test_team_protected_or_unowned_grants_rejected(api, permission):
    client, _, chief, _, headers = api
    h = headers(chief)
    team_id = make_team(client, h)
    assert client.post(f"/api/v1/teams/{team_id}/permissions", headers=h,
                       json={"permissions": [permission]}).status_code == 403


def test_effective_permissions_only_current_active_members_and_teams(api):
    client, session, chief, engineer, headers = api
    h = headers(chief)
    team_id = make_team(client, h)
    client.post(f"/api/v1/teams/{team_id}/permissions", headers=h, json={"permissions": ["startTechnicalWork"]})
    client.post(f"/api/v1/teams/{team_id}/members", headers=h, json={"user_id": str(engineer.id)})
    endpoint = "/api/v1/teams/effective-permissions"
    assert client.get(endpoint, headers=headers(engineer)).json() == ["startTechnicalWork"]
    client.post(f"/api/v1/teams/{team_id}/active", headers=h, json={"is_active": False})
    assert client.get(endpoint, headers=headers(engineer)).json() == []
    client.post(f"/api/v1/teams/{team_id}/active", headers=h, json={"is_active": True})
    client.post(f"/api/v1/teams/{team_id}/members/{engineer.id}/remove", headers=h, json={})
    assert client.get(endpoint, headers=headers(engineer)).json() == []
    client.post(f"/api/v1/teams/{team_id}/members", headers=h, json={"user_id": str(engineer.id)})
    client.post(f"/api/v1/teams/{team_id}/archive", headers=h, json={})
    assert client.get(endpoint, headers=headers(engineer)).json() == []
    # Imported protected team grants cannot elevate effective access either.
    team = session.get(Team, __import__('uuid').UUID(team_id))
    team.is_archived, team.is_active = False, True
    team.permissions = ["manageUsers", "startTechnicalWork"]
    session.commit()
    assert client.get(endpoint, headers=headers(engineer)).json() == ["startTechnicalWork"]
    assert client.get("/api/v1/users", headers=headers(engineer)).status_code == 403


def test_authenticated_directory_is_minimal_and_reads_need_session(api):
    client, _, chief, engineer, headers = api
    assert client.get("/api/v1/directory").status_code == 401
    rows = client.get("/api/v1/directory", headers=headers(engineer)).json()
    assert len(rows) == 2
    assert all("permissions" not in row and "password_hash" not in row for row in rows)
    assert client.get("/api/v1/users", headers=headers(engineer)).status_code == 403
    assert len(client.get("/api/v1/users", headers=headers(chief)).json()) == 2
