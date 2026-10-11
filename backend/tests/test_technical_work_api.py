from datetime import datetime, timezone
from importlib import import_module
from uuid import UUID, uuid4

import pytest
import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations

from app.models.technical_work import TechnicalWork, TechnicalWorkAssignment
from app.models.team import Team, TeamMembership
from app.models.user import User, UserRole
from tests.test_management_api import api, make_team


def report(client, headers, **changes):
    data = dict(submission_id=str(uuid4()), title=' Test bildirim ',
                description=' Saha açıklaması ', location=' Test km 1 ', category='roadSurface')
    data.update(changes)
    return client.post('/api/v1/technical-works', headers=headers, json=data)


def assign(client, headers, work, *, team=None, user=None, revision=0):
    return client.post(f'/api/v1/technical-works/{work}/assign', headers=headers,
        json=dict(priority='critical', assigned_to_team_id=team,
                  assigned_to_user_id=str(user) if user else None, expected_revision=revision))


def test_report_owned_server_fields_trim_and_persistence(api):
    client, session, chief, _, headers = api
    response = report(client, headers(chief))
    assert response.status_code == 201
    work = response.json()
    assert UUID(work['id']) and work['created_by_user_id'] == str(chief.id)
    assert work['title'] == 'Test bildirim' and work['status'] == 'reported'
    assert work['priority'] == 'normal' and work['revision'] == 0
    assert work['assigned_to_team_id'] is None and work['assigned_to_user_id'] is None
    assert work['started_at'] is None and work['started_by_user_id'] is None
    assert session.get(TechnicalWork, UUID(work['id'])) is not None
    assert client.get(f"/api/v1/technical-works/{work['id']}", headers=headers(chief)).json() == work


def test_idempotency_retry_same_request_one_record_and_changed_input_conflicts(api):
    client, session, chief, _, headers = api
    key = str(uuid4())
    first = report(client, headers(chief), submission_id=key)
    second = report(client, headers(chief), submission_id=key)
    assert first.json()['id'] == second.json()['id']
    assert session.scalar(sa.select(sa.func.count()).select_from(TechnicalWork)) == 1
    assert report(client, headers(chief), submission_id=key, title='Different').status_code == 409
    chief.permissions = []
    session.commit()
    assert report(client, headers(chief), submission_id=key).status_code == 403


@pytest.mark.parametrize('changes', [dict(title='  '), dict(description=' '), dict(location=' '),
    dict(category='unknown'), dict(title='x'*101), dict(priority='critical'),
    dict(created_by_user_id=str(uuid4())), dict(status='completed')])
def test_invalid_or_forged_report_input_rejected(api, changes):
    client, _, chief, _, headers = api
    assert report(client, headers(chief), **changes).status_code == 422


def test_report_permission_delegation_active_membership_and_protected_grants(api):
    client, session, chief, engineer, headers = api
    assert report(client, headers(engineer)).status_code == 403
    team_id = make_team(client, headers(chief))
    team = session.get(Team, UUID(team_id))
    team.permissions = ['createFieldReport', 'viewAllTechnicalWork']
    member = TeamMembership(team_id=team.id, user_id=engineer.id, is_active=True)
    session.add(member)
    session.commit()
    own = report(client, headers(engineer))
    assert own.status_code == 201
    other = report(client, headers(chief)).json()['id']
    assert [work['id'] for work in client.get('/api/v1/technical-works', headers=headers(engineer)).json()] == [own.json()['id']]
    assert client.get(f'/api/v1/technical-works/{other}', headers=headers(engineer)).status_code == 403
    member.is_active = False
    session.commit()
    assert report(client, headers(engineer)).status_code == 403


def test_assign_team_then_person_clears_old_target_and_preserves_audit(api):
    client, session, chief, engineer, headers = api
    work_id = report(client, headers(chief)).json()['id']
    team_id = make_team(client, headers(chief))
    first = assign(client, headers(chief), work_id, team=team_id)
    assert first.status_code == 200 and first.json()['assigned_to_team_id'] == team_id
    second = assign(client, headers(chief), work_id, user=engineer.id, revision=1)
    assert second.status_code == 200
    work = second.json()
    assert work['assigned_to_team_id'] is None and work['assigned_to_user_id'] == str(engineer.id)
    assert work['status'] == 'assigned' and work['revision'] == 2 and work['priority'] == 'critical'
    history = client.get(f'/api/v1/technical-works/{work_id}/assignments', headers=headers(chief)).json()
    assert len(history) == 2 and history[1]['previous_team_id'] == team_id
    assert history[0]['assigned_by_user_id'] == str(chief.id)
    assert history[0]['assigned_at'] and history[0]['id'] != history[1]['id']
    assert len(session.scalars(sa.select(TechnicalWorkAssignment)).all()) == 2


def test_stale_assignment_only_one_revision_wins(api):
    client, session, chief, engineer, headers = api
    work = report(client, headers(chief)).json()['id']
    team = make_team(client, headers(chief))
    assert assign(client, headers(chief), work, user=engineer.id).status_code == 200
    rejected = assign(client, headers(chief), work, team=team)
    assert rejected.status_code == 409 and rejected.json()['detail']['code'] == 'work_revision_conflict'
    assert session.get(TechnicalWork, UUID(work)).assigned_to_user_id == engineer.id
    assert session.scalar(sa.select(sa.func.count()).select_from(TechnicalWorkAssignment)) == 1


@pytest.mark.parametrize('state', ['inProgress', 'onHold', 'awaitingCompletionApproval', 'completed', 'cancelled'])
def test_assignment_invalid_state_rejected_after_authorization(api, state):
    client, session, chief, engineer, headers = api
    work = report(client, headers(chief)).json()['id']
    session.get(TechnicalWork, UUID(work)).status = state
    session.commit()
    assert assign(client, headers(chief), work, user=engineer.id).json()['detail']['code'] == 'work_assignment_invalid_state'
    denied = assign(client, headers(engineer), work, user=engineer.id)
    assert denied.status_code == 403 and denied.json()['detail']['code'] == 'not_allowed'


def test_assignment_requires_direct_global_visibility_and_assignment_permission(api):
    client, session, chief, engineer, headers = api
    work = report(client, headers(chief)).json()['id']
    for permissions in [[], ['assignTechnicalWork'], ['viewAllTechnicalWork']]:
        chief.permissions = permissions
        session.commit()
        assert assign(client, headers(chief), work, user=engineer.id).status_code == 403
        assert client.get('/api/v1/technical-works/assignment-targets', headers=headers(chief)).status_code == 403


@pytest.mark.parametrize('invalid', ['passive_team', 'archived_team', 'inactive_user', 'wrong_role', 'no_target', 'two_targets'])
def test_assignment_targets_source_of_truth_validation(api, invalid):
    client, session, chief, engineer, headers = api
    work = report(client, headers(chief)).json()['id']
    team_id = make_team(client, headers(chief))
    team = session.get(Team, UUID(team_id))
    if invalid == 'passive_team': team.is_active = False
    if invalid == 'archived_team': team.is_archived = True
    if invalid == 'inactive_user': engineer.is_active = False
    if invalid == 'wrong_role': engineer.role = UserRole.driver
    session.commit()
    response = assign(client, headers(chief), work,
        team=team_id if invalid in ('passive_team', 'archived_team', 'two_targets') else None,
        user=engineer.id if invalid in ('inactive_user', 'wrong_role', 'two_targets') else None)
    assert response.status_code == 422
    assert session.scalar(sa.select(sa.func.count()).select_from(TechnicalWorkAssignment)) == 0


def test_targets_use_current_active_engineers_and_teams(api):
    client, session, chief, engineer, headers = api
    team = make_team(client, headers(chief))
    result = client.get('/api/v1/technical-works/assignment-targets', headers=headers(chief)).json()
    assert {row['id'] for row in result} == {str(engineer.id), team}
    assert all(row['name'] for row in result)
    session.get(Team, UUID(team)).is_archived = True
    engineer.is_active = False
    session.commit()
    assert client.get('/api/v1/technical-works/assignment-targets', headers=headers(chief)).json() == []


def test_direct_assignee_creator_and_explicit_global_chief_read(api):
    client, _, chief, engineer, headers = api
    work = report(client, headers(chief)).json()['id']
    assert assign(client, headers(chief), work, user=engineer.id).status_code == 200
    assert client.get(f'/api/v1/technical-works/{work}', headers=headers(engineer)).status_code == 200
    assert client.get(f'/api/v1/technical-works/{work}/assignments', headers=headers(engineer)).status_code == 200
    assert client.get('/api/v1/technical-works?assigned_only=true', headers=headers(engineer)).json()[0]['id'] == work


@pytest.mark.parametrize('blocked', [None, 'membership', 'team', 'archive', 'user'])
def test_active_assigned_team_access_and_no_state_existence_leak(api, blocked):
    client, session, chief, engineer, headers = api
    work = report(client, headers(chief)).json()['id']
    team_id = make_team(client, headers(chief))
    team = session.get(Team, UUID(team_id))
    member = TeamMembership(team_id=team.id, user_id=engineer.id, is_active=True)
    session.add(member)
    session.commit()
    assert assign(client, headers(chief), work, team=team_id).status_code == 200
    if blocked == 'membership': member.is_active = False
    if blocked == 'team': team.is_active = False
    if blocked == 'archive': team.is_archived = True
    if blocked == 'user': engineer.is_active = False
    session.commit()
    result = client.get('/api/v1/technical-works?assigned_only=true', headers=headers(engineer))
    detail = client.get(f'/api/v1/technical-works/{work}', headers=headers(engineer))
    history = client.get(f'/api/v1/technical-works/{work}/assignments', headers=headers(engineer))
    if blocked is None:
        assert len(result.json()) == 1 and detail.status_code == history.status_code == 200
    else:
        if blocked != 'user': assert result.json() == []
        missing = client.get(f'/api/v1/technical-works/{uuid4()}', headers=headers(engineer))
        assert detail.status_code == history.status_code == missing.status_code == 403
        assert detail.json() == missing.json()


def test_unrelated_read_denial_missing_equals_existing_and_assignment_not_leaked(api):
    client, _, chief, engineer, headers = api
    work = report(client, headers(chief)).json()['id']
    responses = [client.get(f'/api/v1/technical-works/{id}', headers=headers(engineer)) for id in (work, uuid4())]
    assert responses[0].json() == responses[1].json() == {'detail': {'code': 'technical_work_read_not_allowed'}}
    assert client.get('/api/v1/technical-works', headers=headers(engineer)).json() == []
    assert client.get(f'/api/v1/technical-works/{work}/assignments', headers=headers(engineer)).status_code == 403


def test_server_archive_guard_open_assignment_and_history_kept_when_closed(api):
    client, session, chief, _, headers = api
    work_id = report(client, headers(chief)).json()['id']
    team = make_team(client, headers(chief))
    assert assign(client, headers(chief), work_id, team=team).status_code == 200
    result = client.post(f'/api/v1/teams/{team}/archive', headers=headers(chief), json={})
    assert result.status_code == 409 and result.json()['detail']['code'] == 'team_has_open_work'
    work = session.get(TechnicalWork, UUID(work_id))
    work.status = 'completed'
    session.commit()
    assert client.post(f'/api/v1/teams/{team}/archive', headers=headers(chief), json={}).status_code == 200
    assert work.assigned_to_team_id == UUID(team)
    assert session.scalar(sa.select(sa.func.count()).select_from(TechnicalWorkAssignment)) == 1


def test_work_migration_no_demo_seed_and_database_target_constraint(monkeypatch):
    migration = import_module('migrations.versions.d1b9e206f734_technical_work_foundation')
    engine = sa.create_engine('sqlite://')
    with engine.begin() as connection:
        parent_metadata = sa.MetaData()
        sa.Table('users', parent_metadata, sa.Column('id', sa.Uuid(), primary_key=True))
        sa.Table('teams', parent_metadata, sa.Column('id', sa.Uuid(), primary_key=True))
        parent_metadata.create_all(connection)
        monkeypatch.setattr(migration, 'op', Operations(MigrationContext.configure(connection)))
        migration.upgrade()
        metadata = sa.MetaData()
        works = sa.Table('technical_works', metadata, autoload_with=connection)
        assert connection.execute(sa.select(works)).all() == []
        with pytest.raises(sa.exc.IntegrityError):
            connection.execute(works.insert().values(id=uuid4().hex, submission_id=uuid4().hex, title='T',
                description='D', location='L', category='other', priority='normal', status='assigned',
                created_by_user_id=uuid4().hex, created_at=datetime.now(timezone.utc), revision=0,
                assigned_to_user_id=uuid4().hex, assigned_to_team_id=uuid4().hex))
        migration.downgrade()
        assert 'technical_works' not in sa.inspect(connection).get_table_names()
    engine.dispose()
