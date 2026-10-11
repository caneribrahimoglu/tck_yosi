from importlib import import_module
from uuid import uuid4
from datetime import datetime, timedelta

import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations


def test_team_migration_persists_seed_and_grants_only_initial_chief(monkeypatch):
    migration = import_module("migrations.versions.c9a4237b1d02_teams_and_chief_user_management")
    engine = sa.create_engine("sqlite://")
    metadata = sa.MetaData()
    users = sa.Table("users", metadata, sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("role", sa.String()), sa.Column("created_at", sa.DateTime()),
        sa.Column("permissions", sa.JSON()))
    metadata.create_all(engine)
    first, second, engineer = uuid4(), uuid4(), uuid4()
    now = datetime.now()
    with engine.begin() as connection:
        connection.execute(users.insert(), [
            dict(id=first, role="chief", created_at=now, permissions=["manageTeamPermissions"]),
            dict(id=second, role="chief", created_at=now+timedelta(seconds=1), permissions=[]),
            dict(id=engineer, role="engineer", created_at=now, permissions=[]),
        ])
        monkeypatch.setattr(migration, "op", Operations(MigrationContext.configure(connection)))
        migration.upgrade()
        rows = {row.id: row.permissions for row in connection.execute(sa.select(users))}
        assert set(rows[first]) == {"manageUsers", "manageTeamPermissions"}
        assert rows[second] == [] and rows[engineer] == []
        teams = sa.Table("teams", sa.MetaData(), autoload_with=connection)
        seeded = connection.execute(sa.select(teams)).one()
        assert seeded.name == "Teknik Ekip" and seeded.is_active and not seeded.is_archived
        members = sa.Table("team_memberships", sa.MetaData(), autoload_with=connection)
        assert connection.execute(sa.select(members)).all() == []
        # The database, not only a preflight query, owns name uniqueness.
        import pytest
        with pytest.raises(sa.exc.IntegrityError):
            connection.execute(teams.insert().values(id=uuid4().hex, name="TEKNİK EKİP",
                normalized_name="teknik ekip", description="", permissions=[]))
    engine.dispose()
