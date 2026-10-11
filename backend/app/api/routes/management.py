from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.api.dependencies import DatabaseSession, require_password_change_complete
from app.core.security import PasswordPolicyError, hash_password, validate_new_password
from app.models.permission import AppPermission
from app.models.team import Team, TeamMembership
from app.models.user import User
from app.models.technical_work import TechnicalWork
from app.schemas.auth import MessageResponse, UserResponse
from app.schemas.management import (
    ActiveInput, DirectoryUserResponse, MemberInput, MembershipResponse,
    PasswordResetInput, PermissionsInput, TeamInput, TeamResponse, UserCreate,
)
from app.services.management_policy import (
    CREATABLE_ROLES, TEAM_PROTECTED_PERMISSIONS, fail, manageable_user,
    normalize_team_name, require_manager, validate_grants,
)

router = APIRouter(tags=["management"])
BusinessUser = Annotated[User, Depends(require_password_change_complete)]


def commit(session: DatabaseSession, conflict: str):
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        fail(conflict)


def password_hash(password: str) -> str:
    try:
        validate_new_password(password)
    except PasswordPolicyError:
        fail("invalid_password", 422)
    return hash_password(password)


@router.get("/directory", response_model=list[DirectoryUserResponse])
def directory(session: DatabaseSession, actor: BusinessUser):
    # Minimal name/role directory for this single-organization application.
    # Direct grants and password hashes are intentionally not exposed here.
    return session.scalars(select(User).order_by(User.full_name)).all()


@router.get("/users", response_model=list[UserResponse])
def users(session: DatabaseSession, actor: BusinessUser):
    require_manager(session, actor.id, AppPermission.manageUsers)
    return session.scalars(select(User).order_by(User.full_name)).all()


@router.post("/users", response_model=UserResponse, status_code=201)
def create_user(data: UserCreate, session: DatabaseSession, actor: BusinessUser):
    require_manager(session, actor.id, AppPermission.manageUsers)
    if data.role not in CREATABLE_ROLES:
        fail("protected_role", 403)
    user = User(full_name=data.full_name, username=data.username.lower(), role=data.role,
                password_hash=password_hash(data.temporary_password.get_secret_value()),
                permissions=[], must_change_password=True, is_active=True)
    session.add(user)
    commit(session, "username_exists")
    return user


@router.post("/users/{user_id}/active", response_model=UserResponse)
def user_active(user_id: UUID, data: ActiveInput, session: DatabaseSession, actor: BusinessUser):
    actor = require_manager(session, actor.id, AppPermission.manageUsers)
    user = manageable_user(session, user_id, actor)
    user.is_active = data.is_active
    commit(session, "user_conflict")
    return user


@router.post("/users/{user_id}/permissions", response_model=UserResponse)
def user_permissions(user_id: UUID, data: PermissionsInput, session: DatabaseSession, actor: BusinessUser):
    actor = require_manager(session, actor.id, AppPermission.manageUsers)
    grants = validate_grants(actor, data.permissions, team=False)
    user = manageable_user(session, user_id, actor)
    user.permissions = grants
    commit(session, "user_conflict")
    return user


@router.post("/users/{user_id}/reset-password", response_model=MessageResponse)
def reset_password(user_id: UUID, data: PasswordResetInput, session: DatabaseSession, actor: BusinessUser):
    actor = require_manager(session, actor.id, AppPermission.manageUsers)
    user = manageable_user(session, user_id, actor)
    user.password_hash = password_hash(data.temporary_password.get_secret_value())
    user.must_change_password = True
    commit(session, "user_conflict")
    return {"message": "Geçici parola yenilendi. İlk girişte değiştirilmelidir."}


@router.get("/teams", response_model=list[TeamResponse])
def teams(session: DatabaseSession, actor: BusinessUser):
    return session.scalars(select(Team).order_by(Team.name)).all()


@router.get("/teams/memberships", response_model=list[MembershipResponse])
def memberships(session: DatabaseSession, actor: BusinessUser):
    return session.scalars(select(TeamMembership)).all()


@router.get("/teams/effective-permissions", response_model=list[AppPermission])
def effective_permissions(session: DatabaseSession, actor: BusinessUser):
    delegated = session.scalars(select(Team).join(TeamMembership, TeamMembership.team_id == Team.id)
                               .where(TeamMembership.user_id == actor.id,
                                      TeamMembership.is_active.is_(True), Team.is_active.is_(True),
                                      Team.is_archived.is_(False))).all()
    permissions = set(actor.permissions)
    for team in delegated:
        # Fail closed even if legacy/imported data contains protected grants.
        permissions.update(set(team.permissions) - TEAM_PROTECTED_PERMISSIONS)
    return sorted(permissions)


def get_team(session: DatabaseSession, team_id: UUID, *, mutable=True) -> Team:
    team = session.scalar(select(Team).where(Team.id == team_id).with_for_update())
    if team is None:
        fail("team_not_found", 404)
    if mutable and team.is_archived:
        fail("team_archived")
    return team


def unique_name(session: DatabaseSession, name: str, *, excluding: UUID | None = None, create=False):
    normalized = normalize_team_name(name)
    query = select(Team).where(Team.normalized_name == normalized)
    if excluding is not None:
        query = query.where(Team.id != excluding)
    existing = session.scalar(query)
    if existing is not None:
        if create and existing.is_archived:
            fail("archived_team_name", team_id=str(existing.id), team_name=existing.name)
        fail("team_name_exists")
    return normalized


@router.post("/teams", response_model=TeamResponse, status_code=201)
def create_team(data: TeamInput, session: DatabaseSession, actor: BusinessUser):
    require_manager(session, actor.id, AppPermission.manageTeamPermissions)
    team = Team(name=data.name, normalized_name=unique_name(session, data.name, create=True),
                description=data.description, permissions=[], is_active=True, is_archived=False)
    session.add(team)
    commit(session, "team_name_exists")
    return team


@router.post("/teams/{team_id}/details", response_model=TeamResponse)
def update_team(team_id: UUID, data: TeamInput, session: DatabaseSession, actor: BusinessUser):
    require_manager(session, actor.id, AppPermission.manageTeamPermissions)
    team = get_team(session, team_id)
    team.normalized_name = unique_name(session, data.name, excluding=team_id)
    team.name, team.description = data.name, data.description
    commit(session, "team_name_exists")
    return team


@router.post("/teams/{team_id}/active", response_model=TeamResponse)
def team_active(team_id: UUID, data: ActiveInput, session: DatabaseSession, actor: BusinessUser):
    require_manager(session, actor.id, AppPermission.manageTeamPermissions)
    team = get_team(session, team_id)
    team.is_active = data.is_active
    commit(session, "team_conflict")
    return team


@router.post("/teams/{team_id}/archive", response_model=TeamResponse)
def archive_team(team_id: UUID, session: DatabaseSession, actor: BusinessUser):
    require_manager(session, actor.id, AppPermission.manageTeamPermissions)
    team = get_team(session, team_id, mutable=False)
    if not team.is_archived and session.scalar(select(TechnicalWork.id).where(
            TechnicalWork.assigned_to_team_id == team_id,
            TechnicalWork.status.not_in(("completed", "cancelled"))).limit(1)) is not None:
        fail("team_has_open_work")
    team.is_archived, team.is_active = True, False
    commit(session, "team_conflict")
    return team


@router.post("/teams/{team_id}/restore", response_model=TeamResponse)
def restore_team(team_id: UUID, session: DatabaseSession, actor: BusinessUser):
    require_manager(session, actor.id, AppPermission.manageTeamPermissions)
    team = get_team(session, team_id, mutable=False)
    if not team.is_archived:
        fail("team_not_archived")
    unique_name(session, team.name, excluding=team_id)
    team.is_archived, team.is_active = False, False
    commit(session, "team_conflict")
    return team


@router.post("/teams/{team_id}/members", response_model=MembershipResponse, status_code=201)
def add_member(team_id: UUID, data: MemberInput, session: DatabaseSession, actor: BusinessUser):
    require_manager(session, actor.id, AppPermission.manageTeamPermissions)
    get_team(session, team_id)
    user = session.get(User, data.user_id)
    if user is None or not user.is_active:
        fail("active_user_required", 422)
    membership = session.scalar(select(TeamMembership).where(
        TeamMembership.team_id == team_id, TeamMembership.user_id == data.user_id))
    if membership is not None and membership.is_active:
        fail("member_exists")
    if membership is None:
        membership = TeamMembership(team_id=team_id, user_id=data.user_id)
        session.add(membership)
    else:
        membership.is_active = True
    commit(session, "member_exists")
    return membership


@router.post("/teams/{team_id}/members/{user_id}/remove", response_model=MessageResponse)
def remove_member(team_id: UUID, user_id: UUID, session: DatabaseSession, actor: BusinessUser):
    require_manager(session, actor.id, AppPermission.manageTeamPermissions)
    get_team(session, team_id)
    membership = session.scalar(select(TeamMembership).where(
        TeamMembership.team_id == team_id, TeamMembership.user_id == user_id))
    if membership is not None:
        membership.is_active = False
    commit(session, "team_conflict")
    return {"message": "Üyelik kaldırıldı."}


@router.post("/teams/{team_id}/permissions", response_model=TeamResponse)
def team_permissions(team_id: UUID, data: PermissionsInput, session: DatabaseSession, actor: BusinessUser):
    actor = require_manager(session, actor.id, AppPermission.manageTeamPermissions)
    grants = validate_grants(actor, data.permissions, team=True)
    team = get_team(session, team_id)
    team.permissions = grants
    commit(session, "team_conflict")
    return team
