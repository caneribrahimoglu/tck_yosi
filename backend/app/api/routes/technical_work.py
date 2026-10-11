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
