"""Persistent teams/memberships and explicit initial chief user-management grant."""
from uuid import uuid4

from alembic import op
import sqlalchemy as sa

revision = "c9a4237b1d02"
down_revision = "b82d1f9c0a41"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("teams",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("normalized_name", sa.String(120), nullable=False, unique=True),
        sa.Column("description", sa.String(2000), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("is_archived", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("permissions", sa.JSON(), nullable=False))
    op.create_table("team_memberships",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("team_id", sa.Uuid(), sa.ForeignKey("teams.id"), nullable=False),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.UniqueConstraint("team_id", "user_id", name="uq_team_member"))
    connection = op.get_bind()
    teams = sa.table("teams", sa.column("id", sa.Uuid()), sa.column("name"),
                     sa.column("normalized_name"), sa.column("description"),
                     sa.column("is_active", sa.Boolean()), sa.column("is_archived", sa.Boolean()),
                     sa.column("permissions", sa.JSON()))
    connection.execute(teams.insert().values(id=uuid4(), name="Teknik Ekip", normalized_name="teknik ekip",
        description="Teknik saha operasyonlarını yürüten ekip.", is_active=True, is_archived=False,
        permissions=["startTechnicalWork", "addTechnicalWorkProgress", "pauseTechnicalWork",
                     "resumeTechnicalWork", "requestTechnicalWorkCompletion", "createFieldReport", "viewReports"]))
    users = sa.table("users", sa.column("id", sa.Uuid()), sa.column("role"),
                     sa.column("created_at"), sa.column("permissions", sa.JSON()))
    initial = connection.execute(sa.select(users.c.id, users.c.permissions).where(users.c.role == "chief")
                                 .order_by(users.c.created_at, users.c.id).limit(1)).first()
    if initial is not None:
        connection.execute(users.update().where(users.c.id == initial.id)
                           .values(permissions=sorted(set(initial.permissions or []) | {"manageUsers"})))


def downgrade():
    # Do not silently revoke a live chief's explicit grant on schema rollback.
    op.drop_table("team_memberships")
    op.drop_table("teams")
