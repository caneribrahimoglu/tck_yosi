from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class TechnicalWorkProgressNote(Base):
    __tablename__ = "technical_work_progress_notes"
    __table_args__ = (
        UniqueConstraint("work_id", "author_user_id", "submission_id", name="uq_progress_submission"),
        CheckConstraint("length(trim(content)) > 0", name="ck_progress_content"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    work_id: Mapped[UUID] = mapped_column(ForeignKey("technical_works.id"), nullable=False, index=True)
    author_user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    submission_id: Mapped[UUID] = mapped_column(nullable=False)
    content: Mapped[str] = mapped_column(String(1000), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class TechnicalWorkHoldRecord(Base):
    __tablename__ = "technical_work_hold_records"
    __table_args__ = (
        CheckConstraint("length(trim(reason)) > 0", name="ck_hold_reason"),
        CheckConstraint(
            "(resumed_by_user_id IS NULL AND resumed_at IS NULL) OR "
            "(resumed_by_user_id IS NOT NULL AND resumed_at IS NOT NULL)", name="ck_hold_resume_metadata"),
        Index("uq_open_work_hold", "work_id", unique=True,
              postgresql_where=text("resumed_at IS NULL"), sqlite_where=text("resumed_at IS NULL")),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    work_id: Mapped[UUID] = mapped_column(ForeignKey("technical_works.id"), nullable=False, index=True)
    held_by_user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    held_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    reason: Mapped[str] = mapped_column(String(1000), nullable=False)
    resumed_by_user_id: Mapped[UUID | None] = mapped_column(ForeignKey("users.id"))
    resumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
