"""Persistent progress notes and hold/resume cycles."""
from alembic import op
import sqlalchemy as sa

revision = "e8a7152c4906"
down_revision = "d1b9e206f734"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("technical_work_progress_notes",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("work_id", sa.Uuid(), sa.ForeignKey("technical_works.id"), nullable=False),
        sa.Column("author_user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("submission_id", sa.Uuid(), nullable=False),
        sa.Column("content", sa.String(1000), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("work_id", "author_user_id", "submission_id", name="uq_progress_submission"),
        sa.CheckConstraint("length(trim(content)) > 0", name="ck_progress_content"))
    op.create_index("ix_technical_work_progress_notes_work_id", "technical_work_progress_notes", ["work_id"])
    op.create_table("technical_work_hold_records",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("work_id", sa.Uuid(), sa.ForeignKey("technical_works.id"), nullable=False),
        sa.Column("held_by_user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("held_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("reason", sa.String(1000), nullable=False),
        sa.Column("resumed_by_user_id", sa.Uuid(), sa.ForeignKey("users.id")),
        sa.Column("resumed_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint("length(trim(reason)) > 0", name="ck_hold_reason"),
        sa.CheckConstraint("(resumed_by_user_id IS NULL AND resumed_at IS NULL) OR (resumed_by_user_id IS NOT NULL AND resumed_at IS NOT NULL)", name="ck_hold_resume_metadata"))
    op.create_index("ix_technical_work_hold_records_work_id", "technical_work_hold_records", ["work_id"])
    op.create_index("uq_open_work_hold", "technical_work_hold_records", ["work_id"], unique=True,
        postgresql_where=sa.text("resumed_at IS NULL"), sqlite_where=sa.text("resumed_at IS NULL"))


def downgrade():
    op.drop_table("technical_work_hold_records")
    op.drop_table("technical_work_progress_notes")
