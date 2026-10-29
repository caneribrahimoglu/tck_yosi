from uuid import UUID

from fastapi import APIRouter
from sqlalchemy import select

from app.api.dependencies import DatabaseSession
from app.api.routes.technical_work import BusinessUser
from app.models.technical_work_completion import TechnicalWorkCompletionRequest
from app.schemas.technical_work_completion import (ApprovalInput, CompletionInput, CompletionResponse,
    CompletionSubmissionResponse, CompletionReviewItem, RejectionInput)
from app.services.technical_work import read_work
from app.services.technical_work_completion import request_completion, pending_completions, review_completion

router = APIRouter(prefix="/technical-works", tags=["technical work completion"])


@router.get("/completion-requests/pending", response_model=list[CompletionReviewItem])
def pending(session: DatabaseSession, actor: BusinessUser):
    return pending_completions(session, actor)


@router.post("/completion-requests/{request_id}/approve", response_model=CompletionSubmissionResponse)
def approve(request_id: UUID, data: ApprovalInput, session: DatabaseSession, actor: BusinessUser):
    work, request = review_completion(session, actor, request_id)
    session.commit()
    return {"work": work, "request": request}


@router.post("/completion-requests/{request_id}/reject", response_model=CompletionSubmissionResponse)
def reject(request_id: UUID, data: RejectionInput, session: DatabaseSession, actor: BusinessUser):
    work, request = review_completion(session, actor, request_id, rejection_reason=data.reason)
    session.commit()
    return {"work": work, "request": request}


@router.get("/{work_id}/completion-requests", response_model=list[CompletionResponse])
def history(work_id: UUID, session: DatabaseSession, actor: BusinessUser):
    read_work(session, actor, work_id)
    return session.scalars(select(TechnicalWorkCompletionRequest).where(
        TechnicalWorkCompletionRequest.work_id == work_id).order_by(
            TechnicalWorkCompletionRequest.requested_at, TechnicalWorkCompletionRequest.id)).all()


@router.post("/{work_id}/completion-requests", response_model=CompletionSubmissionResponse, status_code=201)
def submit(work_id: UUID, data: CompletionInput, session: DatabaseSession, actor: BusinessUser):
    work, request = request_completion(session, actor, work_id, data)
    session.commit()
    return {"work": work, "request": request}
