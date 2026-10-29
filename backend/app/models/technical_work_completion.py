"""Completion history is separate from work state; no edit/delete API."""
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class TechnicalWorkCompletionRequest(Base):
    __tablename__ = "technical_work_completion_requests"
    __table_args__ = (
        UniqueConstraint("work_id", "requested_by_user_id", "submission_id", name="uq_completion_submission"),
        CheckConstraint("length(trim(summary)) > 0", name="ck_completion_summary"),
        CheckConstraint("decision IN ('pending','approved','rejected')", name="ck_completion_decision"),
        CheckConstraint(
            "(decision = 'pending' AND reviewed_by_user_id IS NULL AND reviewed_at IS NULL AND rejection_reason IS NULL) OR "
            "(decision = 'approved' AND reviewed_by_user_id IS NOT NULL AND reviewed_at IS NOT NULL AND rejection_reason IS NULL) OR "
            "(decision = 'rejected' AND reviewed_by_user_id IS NOT NULL AND reviewed_at IS NOT NULL AND "
            "rejection_reason IS NOT NULL AND length(trim(rejection_reason)) > 0)", name="ck_completion_review_metadata"),
        Index("uq_pending_work_completion", "work_id", unique=True,
              postgresql_where=text("decision = 'pending'"), sqlite_where=text("decision = 'pending'")),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    work_id: Mapped[UUID] = mapped_column(ForeignKey("technical_works.id"), nullable=False, index=True)
    requested_by_user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    submission_id: Mapped[UUID] = mapped_column(nullable=False)
    summary: Mapped[str] = mapped_column(String(1000), nullable=False)
    requested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    decision: Mapped[str] = mapped_column(String(16), nullable=False, default="pending")
    reviewed_by_user_id: Mapped[UUID | None] = mapped_column(ForeignKey("users.id"))
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    rejection_reason: Mapped[str | None] = mapped_column(String(1000))
