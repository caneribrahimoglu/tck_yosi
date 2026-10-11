from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.permission import AppPermission
from app.models.user import User, UserRole


# Keep in sync with TeamPermissionPolicy in Flutter; backend is authoritative.
TEAM_PROTECTED_PERMISSIONS = {
    AppPermission.manageUsers.value,
    AppPermission.manageTeamPermissions.value,
    AppPermission.viewAllTechnicalWork.value,
    AppPermission.viewVehicleFleet.value,
    AppPermission.reviewTechnicalWorkCompletion.value,
}
DIRECT_PROTECTED_PERMISSIONS = {
    AppPermission.manageUsers.value, AppPermission.manageTeamPermissions.value,
}
CREATABLE_ROLES = {
    UserRole.driver, UserRole.engineer, UserRole.technician, UserRole.cleaning_staff,
}


def fail(code: str, status: int = 409, **context) -> None:
    raise HTTPException(status_code=status, detail={"code": code, **context})


def require_manager(session: Session, actor_id: UUID, permission: AppPermission) -> User:
    # Reload and lock actual persisted grants; never trust client actorPermissions.
    actor = session.scalar(select(User).where(User.id == actor_id)
                           .with_for_update().execution_options(populate_existing=True))
    if (actor is None or not actor.is_active or actor.must_change_password
            or permission.value not in actor.permissions):
        fail("not_allowed", 403)
    return actor


def validate_grants(actor: User, permissions: list[AppPermission], *, team: bool) -> list[str]:
    requested = {p.value for p in permissions}
    protected = TEAM_PROTECTED_PERMISSIONS if team else DIRECT_PROTECTED_PERMISSIONS
    if requested & protected or not requested.issubset(set(actor.permissions)):
        fail("grant_not_allowed", 403)
    return sorted(requested)


def manageable_user(session: Session, user_id: UUID, actor: User) -> User:
    user = session.scalar(select(User).where(User.id == user_id).with_for_update())
    if user is None:
        fail("user_not_found", 404)
    # Chief cannot lock out themselves or mutate another administrator.
    if user.id == actor.id or user.role not in CREATABLE_ROLES:
        fail("protected_account", 403)
    return user


def normalize_team_name(name: str) -> str:
    return name.strip().replace("İ", "i").replace("I", "ı").lower()
