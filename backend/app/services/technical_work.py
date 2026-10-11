from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import and_, or_, select
from sqlalchemy.orm import Session

from app.models.permission import AppPermission
from app.models.team import Team, TeamMembership
from app.models.technical_work import TechnicalWork, TechnicalWorkAssignment, WorkStatus
from app.models.user import User, UserRole
from app.schemas.technical_work import AssignmentInput, FieldReportInput
from app.services.management_policy import fail, require_manager, TEAM_PROTECTED_PERMISSIONS


CLOSED_STATUSES = (WorkStatus.completed.value, WorkStatus.cancelled.value)


def active_team_ids(session: Session, user_id: UUID):
    return select(Team.id).join(TeamMembership, TeamMembership.team_id == Team.id).where(
        TeamMembership.user_id == user_id, TeamMembership.is_active.is_(True),
        Team.is_active.is_(True), Team.is_archived.is_(False))


def effective_permissions(session: Session, actor: User, *, lock=False) -> set[str]:
    query = select(Team).where(Team.id.in_(active_team_ids(session, actor.id))).order_by(Team.id)
    if lock:
        query = query.with_for_update()
    permissions = set(actor.permissions)
    for team in session.scalars(query):
        permissions.update(set(team.permissions) - TEAM_PROTECTED_PERMISSIONS)
    return permissions


def visibility(session: Session, actor: User, *, assigned_only=False):
    team_matches = TechnicalWork.assigned_to_team_id.in_(active_team_ids(session, actor.id))
    if assigned_only:
        return or_(TechnicalWork.assigned_to_user_id == actor.id,
                   and_(team_matches, TechnicalWork.status.not_in(CLOSED_STATUSES)))
    if AppPermission.viewAllTechnicalWork.value in actor.permissions:
        return True
    return or_(TechnicalWork.created_by_user_id == actor.id,
               TechnicalWork.assigned_to_user_id == actor.id, team_matches)


def read_work(session: Session, actor: User, work_id: UUID) -> TechnicalWork:
    # Filter on authorization in the query itself. Missing/inaccessible both use
    # the same typed denial; no status or existence leak to another account.
    work = session.scalar(select(TechnicalWork).where(
        TechnicalWork.id == work_id, visibility(session, actor)))
    if work is None:
        fail("technical_work_read_not_allowed", 403)
    return work


def create_report(session: Session, actor: User, data: FieldReportInput) -> TechnicalWork:
    # Lock/reload the actor before effective permission or idempotency lookups.
    actor = session.scalar(select(User).where(User.id == actor.id).with_for_update()
                           .execution_options(populate_existing=True))
    if (actor is None or not actor.is_active or actor.must_change_password
            or AppPermission.createFieldReport.value not in effective_permissions(session, actor, lock=True)):
        fail("not_allowed", 403)
    existing = session.scalar(select(TechnicalWork).where(
        TechnicalWork.created_by_user_id == actor.id, TechnicalWork.submission_id == data.submission_id))
    if existing is not None:
        if (existing.title, existing.description, existing.location, existing.category) != (
                data.title, data.description, data.location, data.category.value):
            fail("submission_conflict")
        return existing
    work = TechnicalWork(submission_id=data.submission_id, title=data.title,
        description=data.description, location=data.location, category=data.category.value,
        priority="normal", status="reported", created_by_user_id=actor.id,
        created_at=datetime.now(timezone.utc), revision=0)
    session.add(work)
    session.flush()
    return work


def require_assigner(session: Session, actor: User) -> User:
    actor = require_manager(session, actor.id, AppPermission.assignTechnicalWork)
    # Global allocation is an explicit direct chief-wide capability, not role or
    # a delegated team grant that would allow reassigning someone else's work.
    if AppPermission.viewAllTechnicalWork.value not in actor.permissions:
        fail("not_allowed", 403)
    return actor


def assign_work(session: Session, actor: User, work_id: UUID, data: AssignmentInput) -> TechnicalWork:
    actor = require_assigner(session, actor)
    # Lock target BEFORE work; archive uses the same team lock before checking
    # open assignments. A concurrent archive and assignment cannot both win.
    if data.assigned_to_team_id is not None:
        team = session.scalar(select(Team).where(Team.id == data.assigned_to_team_id).with_for_update())
        if team is None or not team.is_active or team.is_archived:
            fail("assignment_target_not_available", 422)
    else:
        user = session.scalar(select(User).where(User.id == data.assigned_to_user_id).with_for_update())
        if user is None or not user.is_active or user.role != UserRole.engineer:
            fail("assignment_target_not_available", 422)
    work = session.scalar(select(TechnicalWork).where(TechnicalWork.id == work_id).with_for_update()
                          .execution_options(populate_existing=True))
    if work is None:
        fail("technical_work_read_not_allowed", 403)
    if work.revision != data.expected_revision:
        fail("work_revision_conflict")
    if work.status not in ("reported", "awaitingInspection", "assigned"):
        fail("work_assignment_invalid_state")
    session.add(TechnicalWorkAssignment(work_id=work.id, assigned_by_user_id=actor.id,
        assigned_at=datetime.now(timezone.utc), assigned_to_user_id=data.assigned_to_user_id,
        assigned_to_team_id=data.assigned_to_team_id, previous_user_id=work.assigned_to_user_id,
        previous_team_id=work.assigned_to_team_id, priority=data.priority.value, revision=work.revision + 1))
    work.assigned_to_user_id, work.assigned_to_team_id = data.assigned_to_user_id, data.assigned_to_team_id
    work.priority, work.status, work.revision = data.priority.value, "assigned", work.revision + 1
    session.flush()
    return work
