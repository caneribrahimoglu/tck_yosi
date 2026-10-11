from datetime import datetime, timedelta
from importlib import import_module
from uuid import uuid4

from alembic.migration import MigrationContext
from alembic.operations import Operations
import sqlalchemy as sa

from app.models.permission import INITIAL_CHIEF_PERMISSIONS


def test_permission_migration_grants_only_initial_chief(monkeypatch):
    migration = import_module("migrations.versions.b82d1f9c0a41_add_user_permissions")
    assert set(migration.CHIEF_GRANTS) == set(INITIAL_CHIEF_PERMISSIONS) - {"manageUsers"}
    engine = sa.create_engine("sqlite://")
    metadata = sa.MetaData()
    users = sa.Table("users", metadata, sa.Column("id", sa.Uuid(), primary_key=True),
                     sa.Column("role", sa.String()), sa.Column("created_at", sa.DateTime()))
    metadata.create_all(engine)
    initial, later, engineer = uuid4(), uuid4(), uuid4()
    now = datetime.now()
    with engine.begin() as connection:
        connection.execute(users.insert(), [
            {"id": initial, "role": "chief", "created_at": now},
            {"id": later, "role": "chief", "created_at": now + timedelta(seconds=1)},
            {"id": engineer, "role": "engineer", "created_at": now},
        ])
        monkeypatch.setattr(migration, "op", Operations(MigrationContext.configure(connection)))
        migration.upgrade()
        updated = sa.Table("users", sa.MetaData(), autoload_with=connection)
        grants = {str(row.id): row.permissions for row in connection.execute(sa.select(updated))}
        # SQLite reflects UUID as a string without hyphens.
        assert set(grants[initial.hex]) == set(INITIAL_CHIEF_PERMISSIONS) - {"manageUsers"}
        assert grants[later.hex] == []
        assert grants[engineer.hex] == []
    engine.dispose()
