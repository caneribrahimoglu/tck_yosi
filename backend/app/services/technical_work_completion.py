from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.permission import AppPermission
from app.models.technical_work import TechnicalWork
from app.models.technical_work_completion import TechnicalWorkCompletionRequest
from app.models.user import User
from app.schemas.technical_work_completion import CompletionInput
from app.services.management_policy import fail, require_manager
from app.services.technical_work_execution import authorized_locked_work, check_revision


def request_completion(session: Session, actor: User, work_id: UUID, data: CompletionInput):
    # Reuse the actor -> teams -> work lock order and current assignment checks.
    # No existence/state/idempotency lookup is exposed before authorization.
    work = authorized_locked_work(session, actor, work_id, AppPermission.requestTechnicalWorkCompletion,
                                  "technical_work_completion_not_allowed")
    previous = session.scalar(select(TechnicalWorkCompletionRequest).where(
        TechnicalWorkCompletionRequest.work_id == work.id,
        TechnicalWorkCompletionRequest.requested_by_user_id == actor.id,
        TechnicalWorkCompletionRequest.submission_id == data.submission_id))
    if previous is not None:
        if previous.summary != data.summary:
            fail("technical_work_completion_submission_conflict")
        # A lost response can be retried even though the work is now pending.
        return work, previous
    if work.status != "inProgress":
        fail("technical_work_completion_invalid_state")
    check_revision(work, data.expected_revision, "technical_work_completion_revision_conflict")
    if session.scalar(select(TechnicalWorkCompletionRequest.id).where(
            TechnicalWorkCompletionRequest.work_id == work.id,
            TechnicalWorkCompletionRequest.decision == "pending")) is not None:
        fail("technical_work_completion_invalid_state")
    request = TechnicalWorkCompletionRequest(work_id=work.id, requested_by_user_id=actor.id,
        submission_id=data.submission_id, summary=data.summary, requested_at=datetime.now(timezone.utc), decision="pending")
    session.add(request)
    work.status = "awaitingCompletionApproval"
    work.revision += 1
    session.flush()
    return work, request


def require_reviewer(session: Session, actor: User) -> User:
    # Direct persisted grant only. Role/global-read/team grants are not enough.
    return require_manager(session, actor.id, AppPermission.reviewTechnicalWorkCompletion)


def pending_completions(session: Session, actor: User):
    require_reviewer(session, actor)
    rows = session.execute(select(TechnicalWork, TechnicalWorkCompletionRequest).join(
        TechnicalWorkCompletionRequest, TechnicalWorkCompletionRequest.work_id == TechnicalWork.id).where(
            TechnicalWorkCompletionRequest.decision == "pending",
            TechnicalWork.status == "awaitingCompletionApproval").order_by(
                TechnicalWorkCompletionRequest.requested_at, TechnicalWorkCompletionRequest.id)).all()
    return [{"work": work, "request": request} for work, request in rows]


def review_completion(session: Session, actor: User, request_id: UUID, *, rejection_reason: str | None = None):
    actor = require_reviewer(session, actor)  # Before existence or state lookup.
    if rejection_reason is not None:
        rejection_reason = rejection_reason.strip()
        if not rejection_reason or len(rejection_reason) > 1000:
            fail("invalid_input", 422)
    work_id = session.scalar(select(TechnicalWorkCompletionRequest.work_id).where(
        TechnicalWorkCompletionRequest.id == request_id))
    if work_id is None:
        fail("technical_work_completion_review_not_found", 404)
    # Same order as submission: lock work before its history record. Concurrent
    # approve/reject (also by different reviewers) has exactly one winner.
    work = session.scalar(select(TechnicalWork).where(TechnicalWork.id == work_id)
        .with_for_update().execution_options(populate_existing=True))
    request = session.scalar(select(TechnicalWorkCompletionRequest).where(
        TechnicalWorkCompletionRequest.id == request_id).with_for_update().execution_options(populate_existing=True))
    if request.decision != "pending":
        fail("technical_work_completion_already_decided")
    if work is None or work.status != "awaitingCompletionApproval":
        fail("technical_work_completion_review_invalid_state")
    now = datetime.now(timezone.utc)
    request.reviewed_by_user_id, request.reviewed_at = actor.id, now
    if rejection_reason is None:
        request.decision = "approved"
        work.status, work.completed_at = "completed", now
    else:
        request.decision, request.rejection_reason = "rejected", rejection_reason
        work.status = "inProgress"
    work.revision += 1
    session.flush()
    return work, request
