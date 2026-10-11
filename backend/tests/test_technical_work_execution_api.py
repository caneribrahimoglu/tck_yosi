from uuid import UUID, uuid4

import pytest
from sqlalchemy import select

from app.models.team import Team, TeamMembership
from app.models.technical_work import TechnicalWork
from app.models.technical_work_execution import TechnicalWorkHoldRecord, TechnicalWorkProgressNote
from tests.test_management_api import api, make_team
from tests.test_technical_work_api import assign, report

PERMISSIONS = ['startTechnicalWork','addTechnicalWorkProgress','pauseTechnicalWork','resumeTechnicalWork']


def prepare(api, *, team=False, start=False):
    client, session, chief, engineer, headers = api
    engineer.permissions = [] if team else PERMISSIONS[:]
    session.commit()
    work_id = report(client,headers(chief)).json()['id']
    team_id = None
    if team:
        team_id = make_team(client,headers(chief))
        target = session.get(Team,UUID(team_id))
        target.permissions = PERMISSIONS[:]
        session.add(TeamMembership(team_id=target.id,user_id=engineer.id,is_active=True))
        session.commit()
    assert assign(client,headers(chief),work_id,team=team_id,user=None if team else engineer.id).status_code == 200
    if start:
        assert client.post(f'/api/v1/technical-works/{work_id}/start',headers=headers(engineer),json={'expected_revision':1}).status_code == 200
    return work_id, team_id


def action(api, work_id, operation, body, *, actor=None):
    client, _, _, engineer, headers = api
    return client.post(f'/api/v1/technical-works/{work_id}/{operation}',headers=headers(actor or engineer),json=body)


@pytest.mark.parametrize('team',[False,True])
def test_authorized_start_keeps_assignment_records_starter_and_rejects_repeat(api, team):
    client, session, chief, engineer, headers = api
    work_id, team_id = prepare(api,team=team)
    started = action(api,work_id,'start',{'expected_revision':1})
    assert started.status_code == 200
    work = started.json()
    assert work['status']=='inProgress' and work['started_by_user_id']==str(engineer.id)
    assert work['started_at'].endswith('Z') and work['revision']==2
    assert work['assigned_to_team_id']==team_id
    assert work['assigned_to_user_id']==(None if team else str(engineer.id))
    repeat = action(api,work_id,'start',{'expected_revision':1})
    assert repeat.status_code == 409 and repeat.json()['detail']['code']=='technical_work_already_started'
    denied = action(api,work_id,'start',{'expected_revision':1},actor=chief)
    assert denied.status_code==403 and denied.json()['detail']['code']=='technical_work_start_not_allowed'
    current = client.get(f'/api/v1/technical-works/{work_id}',headers=headers(chief)).json()
    assert current == work


@pytest.mark.parametrize('team',[False,True])
def test_progress_server_metadata_order_idempotency_and_read_scope(api,team):
    client, session, chief, engineer, headers = api
    work_id,_ = prepare(api,team=team,start=True)
    key = str(uuid4())
    body = {'submission_id':key,'content':' İlk çalışma notu '}
    first = action(api,work_id,'progress',body)
    second = action(api,work_id,'progress',body)
    assert first.status_code==201 and first.json()==second.json()
    note = first.json()
    assert UUID(note['id']) and note['author_user_id']==str(engineer.id)
    assert note['work_id']==work_id and note['content']=='İlk çalışma notu' and note['created_at'].endswith('Z')
    assert 'submission_id' not in note
    assert action(api,work_id,'progress',{'submission_id':key,'content':'Changed'}).status_code==409
    assert action(api,work_id,'progress',{'submission_id':str(uuid4()),'content':'Second'}).status_code==201
    history = client.get(f'/api/v1/technical-works/{work_id}/progress',headers=headers(chief)).json()
    assert [row['content'] for row in history]==['İlk çalışma notu','Second']
    history[0]['content']='Client alteration'
    assert client.get(f'/api/v1/technical-works/{work_id}/progress',headers=headers(engineer)).json()[0]['content']=='İlk çalışma notu'
    assert len(session.scalars(select(TechnicalWorkProgressNote)).all())==2
    assert client.put(f"/api/v1/technical-works/{work_id}/progress",headers=headers(engineer),json={'content':'edited'}).status_code==405


@pytest.mark.parametrize('team',[False,True])
def test_hold_resume_multiple_cycles_metadata_and_progress_blocked(api,team):
    client, session, chief, engineer, headers = api
    work_id,team_id = prepare(api,team=team,start=True)
    original = client.get(f'/api/v1/technical-works/{work_id}',headers=headers(chief)).json()
    held = action(api,work_id,'hold',{'expected_revision':2,'reason':' Malzeme bekleniyor '})
    assert held.status_code==200
    assert held.json()['work']['status']=='onHold' and held.json()['work']['revision']==3
    record = held.json()['record']
    assert record['reason']=='Malzeme bekleniyor' and record['held_by_user_id']==str(engineer.id)
    assert record['resumed_at'] is None and record['resumed_by_user_id'] is None
    blocked = action(api,work_id,'progress',{'submission_id':str(uuid4()),'content':'Not'})
    assert blocked.status_code==409 and blocked.json()['detail']['code']=='technical_work_progress_invalid_state'
    assert action(api,work_id,'hold',{'expected_revision':2,'reason':'Duplicate'}).status_code==409
    resumed = action(api,work_id,'resume',{'expected_revision':3})
    assert resumed.status_code==200 and resumed.json()['record']['id']==record['id']
    assert resumed.json()['record']['resumed_by_user_id']==str(engineer.id)
    assert resumed.json()['record']['resumed_at'] and resumed.json()['work']['status']=='inProgress'
    for key in ['assigned_to_team_id','assigned_to_user_id','started_by_user_id','started_at']:
        assert resumed.json()['work'][key]==original[key]
    assert action(api,work_id,'resume',{'expected_revision':3}).status_code==409
    assert action(api,work_id,'hold',{'expected_revision':4,'reason':'Second cycle'}).status_code==200
    history = client.get(f'/api/v1/technical-works/{work_id}/holds',headers=headers(chief)).json()
    assert len(history)==2 and history[0]['id']!=history[1]['id']
    assert history[0]['reason']==record['reason'] and history[0]['resumed_at']
    assert history[1]['resumed_at'] is None
    assert len(session.scalars(select(TechnicalWorkHoldRecord)).all())==2


@pytest.mark.parametrize('blocked',['membership','team','archive','user','permission','unassigned'])
@pytest.mark.parametrize('operation',['start','progress','hold','resume'])
def test_mutation_denial_precedes_current_state_and_no_missing_work_leak(api,blocked,operation):
    client, session, chief, engineer, headers = api
    work_id,team_id = prepare(api,team=True,start=True)
    if blocked=='membership': session.scalar(select(TeamMembership)).is_active=False
    if blocked=='team': session.get(Team,UUID(team_id)).is_active=False
    if blocked=='archive': session.get(Team,UUID(team_id)).is_archived=True
    if blocked=='user': engineer.is_active=False
    if blocked=='permission': session.get(Team,UUID(team_id)).permissions=[]
    if blocked=='unassigned': session.get(TechnicalWork,UUID(work_id)).assigned_to_team_id=None
    session.commit()
    body = {'submission_id':str(uuid4()),'content':'X'} if operation=='progress' else {'expected_revision':2}
    if operation=='hold': body['reason']='X'
    existing = action(api,work_id,operation,body)
    missing = action(api,str(uuid4()),operation,body)
    assert existing.status_code==missing.status_code==403
    assert existing.json()==missing.json()
    if blocked!='user': assert existing.json()['detail']['code'].endswith('_not_allowed')


@pytest.mark.parametrize('state',['reported','awaitingInspection','assigned','onHold','awaitingCompletionApproval','completed','cancelled'])
def test_progress_only_in_progress(api,state):
    _,session,_,_,_=api
    work_id,_=prepare(api,start=True)
    session.get(TechnicalWork,UUID(work_id)).status=state
    session.commit()
    response=action(api,work_id,'progress',{'submission_id':str(uuid4()),'content':'X'})
    assert response.status_code==409 and response.json()['detail']['code']=='technical_work_progress_invalid_state'


@pytest.mark.parametrize('operation,state',[('hold','reported'),('hold','assigned'),('hold','awaitingCompletionApproval'),('hold','completed'),('hold','cancelled'),('resume','inProgress'),('resume','assigned'),('resume','completed'),('start','reported'),('start','awaitingInspection')])
def test_invalid_transitions_and_revision_conflicts(api,operation,state):
    _,session,_,_,_=api
    work_id,_=prepare(api)
    session.get(TechnicalWork,UUID(work_id)).status=state
    session.commit()
    body={'expected_revision':1}
    if operation=='hold': body['reason']='X'
    response=action(api,work_id,operation,body)
    assert response.status_code==409 and response.json()['detail']['code'].endswith('_invalid_state')


@pytest.mark.parametrize('operation,body',[('hold',{'expected_revision':2,'reason':'  '}),('progress',{'submission_id':str(uuid4()),'content':'  '}),('progress',{'submission_id':str(uuid4()),'content':123}),('hold',{'expected_revision':2,'reason':'x'*1001}),('start',{'expected_revision':2,'started_by_user_id':str(uuid4())})])
def test_blank_invalid_and_forged_metadata_rejected(api,operation,body):
    work_id,_=prepare(api,start=True)
    assert action(api,work_id,operation,body).status_code==422


def test_current_capabilities_and_chief_read_only_unless_assigned(api):
    client,session,chief,engineer,headers=api
    work_id,_=prepare(api,team=True,start=True)
    root='/api/v1/technical-works'
    assert client.get(root+'/actor-capabilities',headers=headers(engineer)).json()=={'can_start':True}
    assert client.get(root+f'/{work_id}/capabilities',headers=headers(engineer)).json()=={
        'can_start':False,'can_add_progress':True,'can_pause':True,'can_resume':False}
    assert client.get(root+f'/{work_id}/capabilities',headers=headers(chief)).json()=={
        'can_start':False,'can_add_progress':False,'can_pause':False,'can_resume':False}
    assert action(api,work_id,'hold',{'expected_revision':2,'reason':'X'},actor=chief).status_code==403
    engineer.permissions=[]
    session.commit()
    # Team grants remain effective, direct permission isn't required.
    assert client.get(root+f'/{work_id}/capabilities',headers=headers(engineer)).json()['can_pause']


def test_secure_progress_and_hold_history_unrelated_missing_same_denial(api):
    client,session,chief,engineer,headers=api
    work_id,_=prepare(api,start=True)
    action(api,work_id,'progress',{'submission_id':str(uuid4()),'content':'Secret'})
    action(api,work_id,'hold',{'expected_revision':2,'reason':'Secret reason'})
    session.get(TechnicalWork,UUID(work_id)).assigned_to_user_id=chief.id
    session.commit()
    for suffix in ['progress','holds','capabilities']:
        existing=client.get(f'/api/v1/technical-works/{work_id}/{suffix}',headers=headers(engineer))
        missing=client.get(f'/api/v1/technical-works/{uuid4()}/{suffix}',headers=headers(engineer))
        assert existing.status_code==missing.status_code==403 and existing.json()==missing.json()
