"""Authorized lifecycle transitions. All mutation locks precede state changes.

Lock order: actor -> participating teams (ordered) -> work. Assignment/archive
also lock the target team before the work, preventing reversed-lock deadlocks.
"""
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.permission import AppPermission
from app.models.team import Team
from app.models.technical_work import TechnicalWork
from app.models.technical_work_execution import TechnicalWorkHoldRecord, TechnicalWorkProgressNote
from app.models.user import User
from app.schemas.technical_work_execution import HoldInput, ProgressInput, TransitionInput
from app.services.management_policy import fail, TEAM_PROTECTED_PERMISSIONS
from app.services.technical_work import active_team_ids, effective_permissions


def can_execute(session: Session, actor: User, work: TechnicalWork, permission: AppPermission,
                *, locked_team_ids: set[UUID] | None = None) -> bool:
    if not actor.is_active or actor.must_change_password:
        return False
    if locked_team_ids is None:
        permissions = effective_permissions(session, actor)
    else:
        # A concurrently added membership must not introduce an unlocked grant.
        # It becomes eligible on the next operation, when its team is locked too.
        permissions = set(actor.permissions)
        for team in session.scalars(select(Team).where(
                Team.id.in_(locked_team_ids), Team.id.in_(active_team_ids(session, actor.id)))):
            permissions.update(set(team.permissions) - TEAM_PROTECTED_PERMISSIONS)
    if permission.value not in permissions:
        return False
    if work.assigned_to_user_id == actor.id:
        return True
    return work.assigned_to_team_id is not None and session.scalar(
        active_team_ids(session, actor.id).where(Team.id == work.assigned_to_team_id)) is not None


def authorized_locked_work(session: Session, actor: User, work_id: UUID,
                           permission: AppPermission, denial: str) -> TechnicalWork:
    actor = session.scalar(select(User).where(User.id == actor.id).with_for_update()
                           .execution_options(populate_existing=True))
    if actor is None or not actor.is_active or actor.must_change_password:
        fail(denial, 403)
    snapshot = session.get(TechnicalWork, work_id)
    if snapshot is None:
        fail(denial, 403)
    if not can_execute(session, actor, snapshot, permission):
        fail(denial, 403)
    targets = (snapshot.assigned_to_user_id, snapshot.assigned_to_team_id)
    team_ids = set(session.scalars(active_team_ids(session, actor.id)))
    if snapshot.assigned_to_team_id is not None:
        team_ids.add(snapshot.assigned_to_team_id)
    # Membership/permission/active/archive mutations all lock their team row.
    if team_ids:
        session.scalars(select(Team).where(Team.id.in_(team_ids)).order_by(Team.id)
                        .with_for_update().execution_options(populate_existing=True)).all()
    if not can_execute(session, actor, snapshot, permission, locked_team_ids=team_ids):
        fail(denial, 403)
    # Unauthorized actors never lock the work or observe state-specific failures.
    work = session.scalar(select(TechnicalWork).where(TechnicalWork.id == work_id)
                          .with_for_update().execution_options(populate_existing=True))
    if (work is None or targets != (work.assigned_to_user_id, work.assigned_to_team_id)
            or not can_execute(session, actor, work, permission, locked_team_ids=team_ids)):
        fail(denial, 403)
    return work


def check_revision(work: TechnicalWork, expected: int, code: str):
    if work.revision != expected:
        fail(code)


def start_work(session: Session, actor: User, work_id: UUID, data: TransitionInput) -> TechnicalWork:
    work = authorized_locked_work(session, actor, work_id, AppPermission.startTechnicalWork,
                                  "technical_work_start_not_allowed")
    if work.started_at is not None or work.status == "inProgress":
        fail("technical_work_already_started")
    if work.status != "assigned":
        fail("technical_work_start_invalid_state")
    check_revision(work, data.expected_revision, "work_revision_conflict")
    work.status = "inProgress"
    work.started_by_user_id, work.started_at = actor.id, datetime.now(timezone.utc)
    work.revision += 1
    session.flush()
    return work


def add_progress(session: Session, actor: User, work_id: UUID, data: ProgressInput) -> TechnicalWorkProgressNote:
    work = authorized_locked_work(session, actor, work_id, AppPermission.addTechnicalWorkProgress,
                                  "technical_work_progress_not_allowed")
    if work.status != "inProgress":
        fail("technical_work_progress_invalid_state")
    existing = session.scalar(select(TechnicalWorkProgressNote).where(
        TechnicalWorkProgressNote.work_id == work.id, TechnicalWorkProgressNote.author_user_id == actor.id,
        TechnicalWorkProgressNote.submission_id == data.submission_id))
    if existing is not None:
        if existing.content != data.content:
            fail("technical_work_progress_submission_conflict")
        return existing
    note = TechnicalWorkProgressNote(work_id=work.id, author_user_id=actor.id,
        submission_id=data.submission_id, content=data.content, created_at=datetime.now(timezone.utc))
    session.add(note)
    session.flush()
    return note


def hold_work(session: Session, actor: User, work_id: UUID, data: HoldInput):
    work = authorized_locked_work(session, actor, work_id, AppPermission.pauseTechnicalWork,
                                  "technical_work_hold_not_allowed")
    if work.status != "inProgress":
        fail("technical_work_hold_invalid_state")
    check_revision(work, data.expected_revision, "technical_work_hold_transition_conflict")
    record = TechnicalWorkHoldRecord(work_id=work.id, held_by_user_id=actor.id,
        held_at=datetime.now(timezone.utc), reason=data.reason)
    session.add(record)
    work.status, work.revision = "onHold", work.revision + 1
    session.flush()
    return work, record


def resume_work(session: Session, actor: User, work_id: UUID, data: TransitionInput):
    work = authorized_locked_work(session, actor, work_id, AppPermission.resumeTechnicalWork,
                                  "technical_work_hold_not_allowed")
    if work.status != "onHold":
        fail("technical_work_hold_invalid_state")
    check_revision(work, data.expected_revision, "technical_work_hold_transition_conflict")
    record = session.scalar(select(TechnicalWorkHoldRecord).where(
        TechnicalWorkHoldRecord.work_id == work.id, TechnicalWorkHoldRecord.resumed_at.is_(None))
        .with_for_update())
    if record is None:
        fail("technical_work_hold_invalid_state")
    record.resumed_by_user_id, record.resumed_at = actor.id, datetime.now(timezone.utc)
    work.status, work.revision = "inProgress", work.revision + 1
    session.flush()
    return work, record
