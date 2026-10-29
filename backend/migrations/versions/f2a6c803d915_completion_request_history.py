"""Persistent completion submission and history; review is a later slice."""
from alembic import op
import sqlalchemy as sa

revision = "f2a6c803d915"
down_revision = "e8a7152c4906"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("technical_work_completion_requests",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("work_id", sa.Uuid(), sa.ForeignKey("technical_works.id"), nullable=False),
        sa.Column("requested_by_user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("submission_id", sa.Uuid(), nullable=False),
        sa.Column("summary", sa.String(1000), nullable=False),
        sa.Column("requested_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("decision", sa.String(16), nullable=False),
        sa.Column("reviewed_by_user_id", sa.Uuid(), sa.ForeignKey("users.id")),
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
        sa.Column("rejection_reason", sa.String(1000)),
        sa.UniqueConstraint("work_id", "requested_by_user_id", "submission_id", name="uq_completion_submission"),
        sa.CheckConstraint("length(trim(summary)) > 0", name="ck_completion_summary"),
        sa.CheckConstraint("decision IN ('pending','approved','rejected')", name="ck_completion_decision"),
        sa.CheckConstraint(
            "(decision = 'pending' AND reviewed_by_user_id IS NULL AND reviewed_at IS NULL AND rejection_reason IS NULL) OR "
            "(decision = 'approved' AND reviewed_by_user_id IS NOT NULL AND reviewed_at IS NOT NULL AND rejection_reason IS NULL) OR "
            "(decision = 'rejected' AND reviewed_by_user_id IS NOT NULL AND reviewed_at IS NOT NULL AND "
            "rejection_reason IS NOT NULL AND length(trim(rejection_reason)) > 0)", name="ck_completion_review_metadata"))
    op.create_index("ix_technical_work_completion_requests_work_id", "technical_work_completion_requests", ["work_id"])
    op.create_index("uq_pending_work_completion", "technical_work_completion_requests", ["work_id"], unique=True,
        postgresql_where=sa.text("decision = 'pending'"), sqlite_where=sa.text("decision = 'pending'"))


def downgrade():
    op.drop_table("technical_work_completion_requests")
