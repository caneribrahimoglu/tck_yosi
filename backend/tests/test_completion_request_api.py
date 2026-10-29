from uuid import UUID, uuid4

import pytest
from sqlalchemy import select

from app.models.team import Team, TeamMembership
from app.models.technical_work import TechnicalWork
from app.models.technical_work_completion import TechnicalWorkCompletionRequest
from app.models.user import User, UserRole
from tests.test_management_api import api
from tests.test_technical_work_execution_api import prepare, action

PERMISSION = 'requestTechnicalWorkCompletion'


def setup(api, *, team=False):
    work, team_id = prepare(api, team=team, start=True)
    _, session, _, engineer, _ = api
    if team:
        group = session.get(Team, UUID(team_id))
        group.permissions = [*group.permissions, PERMISSION]
    else:
        engineer.permissions = [*engineer.permissions, PERMISSION]
    session.commit()
    return work, team_id


def submit(api, work, *, body=None, actor=None):
    return action(api, work, 'completion-requests', body if body is not None else {
        'submission_id': str(uuid4()), 'summary': ' Çalışma tamamlandı. ', 'expected_revision': 2}, actor=actor)


@pytest.mark.parametrize('team', [False, True])
def test_submit_preserves_assignment_start_and_persists_history_with_names_resolvable_ids(api, team):
    client, session, chief, engineer, headers = api
    work, _ = setup(api, team=team)
    before = client.get(f'/api/v1/technical-works/{work}', headers=headers(chief)).json()
    caps = client.get(f'/api/v1/technical-works/{work}/capabilities', headers=headers(engineer)).json()
    assert caps['can_request_completion'] is True
    response = submit(api, work)
    assert response.status_code == 201
    result = response.json()
    assert result['work']['status'] == 'awaitingCompletionApproval' and result['work']['revision'] == 3
    for key in ['assigned_to_user_id', 'assigned_to_team_id', 'started_at', 'started_by_user_id']:
        assert result['work'][key] == before[key]
    request = result['request']
    assert UUID(request['id']) and request['requested_by_user_id'] == str(engineer.id)
    assert request['summary'] == 'Çalışma tamamlandı.' and request['decision'] == 'pending'
    assert request['requested_at'].endswith('Z')
    assert request['reviewed_by_user_id'] is None and request['reviewed_at'] is None and request['rejection_reason'] is None
    assert 'submission_id' not in request
    url = f'/api/v1/technical-works/{work}/completion-requests'
    assert client.get(url, headers=headers(chief)).json() == [request]
    external_copy = client.get(url, headers=headers(engineer)).json()
    external_copy[0]['summary'] = 'changed'
    assert client.get(url, headers=headers(engineer)).json() == [request]
    # A fresh login and DB read retain the same history, not widget-local state.
    assert client.post('/api/v1/auth/login', json={'username':'muhendis', 'password':'Test-Parola-2026'}).status_code == 200
    session.expire_all()
    assert session.scalars(select(TechnicalWorkCompletionRequest)).one().id == UUID(request['id'])
    pending_caps = client.get(f'/api/v1/technical-works/{work}/capabilities', headers=headers(engineer)).json()
    assert not any(pending_caps.values())
    assert action(api, work, 'progress', {'submission_id': str(uuid4()), 'content':'late note'}).status_code == 409
    assert action(api, work, 'hold', {'expected_revision':3,'reason':'late hold'}).status_code == 409
    assert client.put(url, headers=headers(engineer), json={'summary':'edited'}).status_code == 405
    assert client.delete(url, headers=headers(engineer)).status_code == 405


def test_same_submission_retries_same_record_but_changed_payload_conflicts(api):
    _, session, _, _, _ = api
    work, _ = setup(api)
    body = {'submission_id':str(uuid4()),'summary':'Done','expected_revision':2}
    first = submit(api,work,body=body)
    second = submit(api,work,body=body)
    assert first.status_code == 201 and first.json() == second.json()
    assert submit(api,work,body={**body,'summary':'Different'}).json()['detail']['code'] == 'technical_work_completion_submission_conflict'
    assert submit(api,work).json()['detail']['code'] == 'technical_work_completion_invalid_state'
    assert len(session.scalars(select(TechnicalWorkCompletionRequest)).all()) == 1


@pytest.mark.parametrize('blocked', ['no_permission','unassigned','inactive_user','inactive_membership','inactive_team','archived_team','chief'])
def test_mutation_authorization_before_existence_or_pending_state(api, blocked):
    _, session, chief, engineer, _ = api
    work, team_id = setup(api, team=True)
    assert submit(api,work).status_code == 201
    group = session.get(Team,UUID(team_id))
    actor = engineer
    if blocked == 'no_permission': group.permissions = []
    elif blocked == 'unassigned': session.get(TechnicalWork,UUID(work)).assigned_to_team_id = None
    elif blocked == 'inactive_user': engineer.is_active = False
    elif blocked == 'inactive_membership': session.scalar(select(TeamMembership).where(TeamMembership.user_id==engineer.id)).is_active = False
    elif blocked == 'inactive_team': group.is_active = False
    elif blocked == 'archived_team': group.is_archived = True
    else: actor = chief  # Explicit global view and direct operation grant still do not imply assignment.
    session.commit()
    existing = submit(api,work,actor=actor)
    missing = submit(api,str(uuid4()),actor=actor)
    assert existing.status_code == missing.status_code == 403
    assert existing.json() == missing.json()


@pytest.mark.parametrize('state', ['reported','awaitingInspection','assigned','onHold','awaitingCompletionApproval','completed','cancelled'])
def test_only_in_progress_accepts_completion(api,state):
    _, session, _, _, _ = api
    work, _ = setup(api)
    session.get(TechnicalWork,UUID(work)).status = state
    session.commit()
    response = submit(api,work)
    assert response.status_code == 409 and response.json()['detail']['code'] == 'technical_work_completion_invalid_state'
    assert session.scalars(select(TechnicalWorkCompletionRequest)).all() == []


@pytest.mark.parametrize('patch', [{'summary':''},{'summary':' \n\t '},{'summary':'x'*1001},
                                  {'requested_by_user_id':str(uuid4())},{'decision':'approved'},{'expected_revision':-1}])
def test_blank_oversize_or_forged_system_input_is_rejected(api,patch):
    work, _ = setup(api)
    body = {'submission_id':str(uuid4()),'summary':'Done','expected_revision':2,**patch}
    assert submit(api,work,body=body).status_code == 422


def test_stale_revision_does_not_create_or_change_work(api):
    _, session, _, _, _ = api
    work, _ = setup(api)
    response = submit(api,work,body={'submission_id':str(uuid4()),'summary':'Done','expected_revision':1})
    assert response.json()['detail']['code'] == 'technical_work_completion_revision_conflict'
    assert session.get(TechnicalWork,UUID(work)).status == 'inProgress'
    assert session.scalars(select(TechnicalWorkCompletionRequest)).all() == []


def test_history_requires_current_read_access_and_no_missing_existence_leak(api):
    client, session, chief, engineer, headers = api
    work, team_id = setup(api,team=True)
    assert submit(api,work).status_code == 201
    session.scalar(select(TeamMembership).where(TeamMembership.user_id==engineer.id)).is_active = False
    unrelated = User(username='other', full_name='Other',role=UserRole.engineer,
        is_active=True,must_change_password=False,permissions=[],password_hash=chief.password_hash)
    session.add(unrelated)
    session.commit()
    for actor in [engineer,unrelated]:
        existing = client.get(f'/api/v1/technical-works/{work}/completion-requests',headers=headers(actor))
        missing = client.get(f'/api/v1/technical-works/{uuid4()}/completion-requests',headers=headers(actor))
        assert existing.status_code == missing.status_code == 403 and existing.json() == missing.json()
