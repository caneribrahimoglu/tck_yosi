from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.api.dependencies import DatabaseSession, require_password_change_complete
from app.models.team import Team
from app.models.technical_work import TechnicalWork, TechnicalWorkAssignment
from app.models.user import User, UserRole
from app.schemas.technical_work import AssignmentInput, AssignmentResponse, FieldReportInput, WorkResponse
from app.services.management_policy import fail
from app.services.technical_work import assign_work, create_report, read_work, require_assigner, visibility
from app.models.permission import AppPermission
from app.models.technical_work_execution import TechnicalWorkHoldRecord, TechnicalWorkProgressNote
from app.schemas.technical_work_execution import (ExecutionCapabilities, HoldInput, HoldResponse,
    HoldTransitionResponse, ProgressInput, ProgressResponse, TransitionInput)
from app.services.technical_work import effective_permissions
from app.services.technical_work_execution import add_progress, can_execute, hold_work, resume_work, start_work

router = APIRouter(prefix="/technical-works", tags=["technical works"])
BusinessUser = Annotated[User, Depends(require_password_change_complete)]


@router.get("", response_model=list[WorkResponse])
def list_works(session: DatabaseSession, actor: BusinessUser, assigned_only: bool = False):
    return session.scalars(select(TechnicalWork).where(visibility(session, actor, assigned_only=assigned_only))
                           .order_by(TechnicalWork.created_at.desc(), TechnicalWork.id)).all()


@router.post("", response_model=WorkResponse, status_code=201)
def report(data: FieldReportInput, session: DatabaseSession, actor: BusinessUser):
    try:
        work = create_report(session, actor, data)
        session.commit()
    except IntegrityError:
        session.rollback()
        fail("submission_conflict")
    return work


@router.get("/assignment-targets")
def assignment_targets(session: DatabaseSession, actor: BusinessUser):
    require_assigner(session, actor)
    users = session.scalars(select(User).where(User.is_active.is_(True), User.role == UserRole.engineer)
                            .order_by(User.full_name, User.id)).all()
    teams = session.scalars(select(Team).where(Team.is_active.is_(True), Team.is_archived.is_(False))
                            .order_by(Team.name, Team.id)).all()
    return [{"id": str(user.id), "name": user.full_name, "type": "engineer"} for user in users] + [
        {"id": str(team.id), "name": team.name, "type": "team"} for team in teams]


@router.get("/actor-capabilities")
def actor_capabilities(session: DatabaseSession, actor: BusinessUser):
    return {"can_start": AppPermission.startTechnicalWork.value in effective_permissions(session, actor)}


@router.get("/{work_id}/capabilities", response_model=ExecutionCapabilities)
def capabilities(work_id: UUID, session: DatabaseSession, actor: BusinessUser):
    work = read_work(session, actor, work_id)
    return {
        "can_start": work.status == "assigned" and can_execute(session, actor, work, AppPermission.startTechnicalWork),
        "can_add_progress": work.status == "inProgress" and can_execute(session, actor, work, AppPermission.addTechnicalWorkProgress),
        "can_pause": work.status == "inProgress" and can_execute(session, actor, work, AppPermission.pauseTechnicalWork),
        "can_resume": work.status == "onHold" and can_execute(session, actor, work, AppPermission.resumeTechnicalWork),
        "can_request_completion": work.status == "inProgress" and can_execute(session, actor, work, AppPermission.requestTechnicalWorkCompletion),
    }


@router.get("/{work_id}", response_model=WorkResponse)
def detail(work_id: UUID, session: DatabaseSession, actor: BusinessUser):
    return read_work(session, actor, work_id)


@router.get("/{work_id}/assignments", response_model=list[AssignmentResponse])
def assignments(work_id: UUID, session: DatabaseSession, actor: BusinessUser):
    read_work(session, actor, work_id)
    return session.scalars(select(TechnicalWorkAssignment).where(TechnicalWorkAssignment.work_id == work_id)
                           .order_by(TechnicalWorkAssignment.revision)).all()


@router.post("/{work_id}/assign", response_model=WorkResponse)
def assign(work_id: UUID, data: AssignmentInput, session: DatabaseSession, actor: BusinessUser):
    work = assign_work(session, actor, work_id, data)
    session.commit()
    return work


@router.post("/{work_id}/start", response_model=WorkResponse)
def start(work_id: UUID, data: TransitionInput, session: DatabaseSession, actor: BusinessUser):
    work = start_work(session, actor, work_id, data)
    session.commit()
    return work


@router.get("/{work_id}/progress", response_model=list[ProgressResponse])
def progress_history(work_id: UUID, session: DatabaseSession, actor: BusinessUser):
    read_work(session, actor, work_id)
    return session.scalars(select(TechnicalWorkProgressNote).where(TechnicalWorkProgressNote.work_id == work_id)
                           .order_by(TechnicalWorkProgressNote.created_at, TechnicalWorkProgressNote.id)).all()


@router.post("/{work_id}/progress", response_model=ProgressResponse, status_code=201)
def progress(work_id: UUID, data: ProgressInput, session: DatabaseSession, actor: BusinessUser):
    note = add_progress(session, actor, work_id, data)
    session.commit()
    return note


@router.get("/{work_id}/holds", response_model=list[HoldResponse])
def hold_history(work_id: UUID, session: DatabaseSession, actor: BusinessUser):
    read_work(session, actor, work_id)
    return session.scalars(select(TechnicalWorkHoldRecord).where(TechnicalWorkHoldRecord.work_id == work_id)
                           .order_by(TechnicalWorkHoldRecord.held_at, TechnicalWorkHoldRecord.id)).all()


@router.post("/{work_id}/hold", response_model=HoldTransitionResponse)
def hold(work_id: UUID, data: HoldInput, session: DatabaseSession, actor: BusinessUser):
    work, record = hold_work(session, actor, work_id, data)
    session.commit()
    return {"work": work, "record": record}


@router.post("/{work_id}/resume", response_model=HoldTransitionResponse)
def resume(work_id: UUID, data: TransitionInput, session: DatabaseSession, actor: BusinessUser):
    work, record = resume_work(session, actor, work_id, data)
    session.commit()
    return {"work": work, "record": record}
