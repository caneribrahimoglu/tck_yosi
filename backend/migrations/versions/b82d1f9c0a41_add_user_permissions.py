"""Store explicit user permissions and backfill the initial chief account.

Revision ID: b82d1f9c0a41
Revises: a39ac248ab5b
"""
from alembic import op
import sqlalchemy as sa

revision = "b82d1f9c0a41"
down_revision = "a39ac248ab5b"
branch_labels = None
depends_on = None

# Frozen migration snapshot; future application permission edits must not
# silently change the grants made by this migration.
CHIEF_GRANTS = [
    "viewAssignedVehicle", "viewVehicleFleet", "manageVehicleFleet",
    "createVehicleFaultRecord", "createVehicleMaintenanceRecord",
    "reviewVehicleFaults", "createFieldReport", "viewPersonnel",
    "managePersonnel", "viewReports", "approveOperations",
    "assignTechnicalWork", "startTechnicalWork", "addTechnicalWorkProgress",
    "pauseTechnicalWork", "resumeTechnicalWork", "requestTechnicalWorkCompletion",
    "reviewTechnicalWorkCompletion", "viewAllTechnicalWork", "manageTeamPermissions",
]


def upgrade() -> None:
    op.add_column("users", sa.Column("permissions", sa.JSON(), nullable=False,
                                    server_default=sa.text("'[]'")))
    users = sa.table("users", sa.column("id", sa.Uuid()),
                     sa.column("role", sa.String()),
                     sa.column("created_at", sa.DateTime()),
                     sa.column("permissions", sa.JSON()))
    # Only the oldest chief created by the bootstrap flow receives the initial
    # grants. Other accounts retain an empty, least-privilege permission list.
    initial_chief = (sa.select(users.c.id).where(users.c.role == "chief")
                     .order_by(users.c.created_at, users.c.id).limit(1)
                     .scalar_subquery())
    op.execute(users.update().where(users.c.id == initial_chief)
               .values(permissions=CHIEF_GRANTS))


def downgrade() -> None:
    op.drop_column("users", "permissions")
