"""Persistent field reports, assignments and assignment audit."""
from alembic import op
import sqlalchemy as sa

revision = "d1b9e206f734"
down_revision = "c9a4237b1d02"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("technical_works",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("submission_id", sa.Uuid(), nullable=False),
        sa.Column("title", sa.String(100), nullable=False),
        sa.Column("description", sa.String(1000), nullable=False),
        sa.Column("location", sa.String(150), nullable=False),
        sa.Column("category", sa.String(32), nullable=False),
        sa.Column("priority", sa.String(16), nullable=False),
        sa.Column("status", sa.String(32), nullable=False),
        sa.Column("created_by_user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("assigned_to_user_id", sa.Uuid(), sa.ForeignKey("users.id")),
        sa.Column("assigned_to_team_id", sa.Uuid(), sa.ForeignKey("teams.id")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("planned_at", sa.DateTime(timezone=True)),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
        sa.Column("started_by_user_id", sa.Uuid(), sa.ForeignKey("users.id")),
        sa.Column("started_at", sa.DateTime(timezone=True)),
        sa.UniqueConstraint("created_by_user_id", "submission_id", name="uq_work_submission"),
        sa.CheckConstraint("assigned_to_user_id IS NULL OR assigned_to_team_id IS NULL", name="ck_work_single_target"),
        sa.CheckConstraint("status != 'assigned' OR assigned_to_user_id IS NOT NULL OR assigned_to_team_id IS NOT NULL", name="ck_assigned_work_target"),
        sa.CheckConstraint("revision >= 0", name="ck_work_revision"),
        sa.CheckConstraint("priority IN ('low','normal','high','critical')", name="ck_work_priority"),
        sa.CheckConstraint("status IN ('reported','awaitingInspection','assigned','inProgress','awaitingCompletionApproval','onHold','completed','cancelled')", name="ck_work_status"))
    for column in ("created_by_user_id", "assigned_to_user_id", "assigned_to_team_id"):
        op.create_index(f"ix_technical_works_{column}", "technical_works", [column])
    op.create_table("technical_work_assignments",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("work_id", sa.Uuid(), sa.ForeignKey("technical_works.id"), nullable=False),
        sa.Column("assigned_by_user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("assigned_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("assigned_to_user_id", sa.Uuid(), sa.ForeignKey("users.id")),
        sa.Column("assigned_to_team_id", sa.Uuid(), sa.ForeignKey("teams.id")),
        sa.Column("previous_user_id", sa.Uuid(), sa.ForeignKey("users.id")),
        sa.Column("previous_team_id", sa.Uuid(), sa.ForeignKey("teams.id")),
        sa.Column("priority", sa.String(16), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.UniqueConstraint("work_id", "revision", name="uq_assignment_revision"))
    op.create_index("ix_technical_work_assignments_work_id", "technical_work_assignments", ["work_id"])


def downgrade():
    op.drop_table("technical_work_assignments")
    op.drop_table("technical_works")
