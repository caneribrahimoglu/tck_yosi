from uuid import UUID, uuid4

import pytest
from sqlalchemy import select

from app.models.team import Team, TeamMembership
from app.models.technical_work import TechnicalWork
from app.models.technical_work_completion import TechnicalWorkCompletionRequest
from app.services.technical_work_completion import review_completion
from tests.test_management_api import api
from tests.test_completion_request_api import setup, submit

ROOT='/api/v1/technical-works'


def pending(api, *, team=True):
    work, group = setup(api,team=team)
    response=submit(api,work)
    assert response.status_code==201
    return work,group,response.json()['request']


@pytest.mark.parametrize('decision',['approve','reject'])
def test_reviewer_decides_and_preserves_history_assignment_start_metadata(api,decision):
    client,session,chief,engineer,headers=api
    work,_,request=pending(api)
    before=client.get(f'{ROOT}/{work}',headers=headers(chief)).json()
    queue=client.get(ROOT+'/completion-requests/pending',headers=headers(chief))
    assert queue.status_code==200 and len(queue.json())==1
    assert queue.json()[0]['work']['id']==work and queue.json()[0]['request']==request
    body={} if decision=='approve' else {'reason':' Eksik kontrol giderilmeli. '}
    result=client.post(f"{ROOT}/completion-requests/{request['id']}/{decision}",headers=headers(chief),json=body)
    assert result.status_code==200
    data=result.json()
    assert data['request']['reviewed_by_user_id']==str(chief.id)
    assert data['request']['reviewed_at'].endswith('Z')
    assert data['request']['summary']==request['summary'] and data['request']['requested_at']==request['requested_at']
    assert data['request']['id']==request['id'] and data['request']['requested_by_user_id']==str(engineer.id)
    assert data['work']['revision']==before['revision']+1
    for field in ['assigned_to_user_id','assigned_to_team_id','started_at','started_by_user_id']:
        assert data['work'][field]==before[field]
    if decision=='approve':
        assert data['work']['status']=='completed'
        assert data['request']['decision']=='approved'
        assert data['work']['completed_at']==data['request']['reviewed_at']
        assert data['request']['rejection_reason'] is None
    else:
        assert data['work']['status']=='inProgress' and data['work']['completed_at'] is None
        assert data['request']['decision']=='rejected'
        assert data['request']['rejection_reason']=='Eksik kontrol giderilmeli.'
        # A new submission is a second history record, not an edit of rejection.
        next_request=submit(api,work,body={'submission_id':str(uuid4()),'summary':'Duzeltildi','expected_revision':4})
        assert next_request.status_code==201 and next_request.json()['request']['id']!=request['id']
    history=client.get(f'{ROOT}/{work}/completion-requests',headers=headers(engineer)).json()
    assert history[0]==data['request']
    assert len(history)==(1 if decision=='approve' else 2)
    for repeated in ['approve','reject']:
        again=client.post(f"{ROOT}/completion-requests/{request['id']}/{repeated}",headers=headers(chief),json={} if repeated=='approve' else {'reason':'Other'})
        assert again.status_code==409 and again.json()['detail']['code']=='technical_work_completion_already_decided'
    assert client.get(f'{ROOT}/{work}/completion-requests',headers=headers(chief)).json()==history
    assert len(client.get(ROOT+'/completion-requests/pending',headers=headers(chief)).json())==(0 if decision=='approve' else 1)


@pytest.mark.parametrize('blocked',['role_only','global_view_only','legacy_team_permission','inactive','password_change'])
def test_direct_active_review_permission_required_before_lookup(api,blocked):
    client,session,chief,engineer,headers=api
    _,team_id,request=pending(api)
    actor=chief
    if blocked=='role_only': chief.permissions=[]
    elif blocked=='global_view_only': chief.permissions=['viewAllTechnicalWork']
    elif blocked=='legacy_team_permission':
        actor=engineer
        session.get(Team,UUID(team_id)).permissions=['reviewTechnicalWorkCompletion']
        engineer.permissions=[]
    elif blocked=='inactive': chief.is_active=False
    else: chief.must_change_password=True
    session.commit()
    assert client.get(ROOT+'/completion-requests/pending',headers=headers(actor)).status_code==403
    for decision in ['approve','reject']:
        body={} if decision=='approve' else {'reason':'Reason'}
        existing=client.post(f"{ROOT}/completion-requests/{request['id']}/{decision}",headers=headers(actor),json=body)
        missing=client.post(f'{ROOT}/completion-requests/{uuid4()}/{decision}',headers=headers(actor),json=body)
        assert existing.status_code==missing.status_code==403 and existing.json()==missing.json()
    session.expire_all()
    assert session.get(TechnicalWorkCompletionRequest,UUID(request['id'])).decision=='pending'


def test_explicit_direct_permission_not_role_controls_review(api):
    client,session,_,engineer,headers=api
    _,_,request=pending(api)
    engineer.permissions=['reviewTechnicalWorkCompletion']
    session.commit()
    assert client.get(ROOT+'/completion-requests/pending',headers=headers(engineer)).status_code==200
    assert client.post(f"{ROOT}/completion-requests/{request['id']}/approve",headers=headers(engineer),json={}).status_code==200


@pytest.mark.parametrize('body',[{'reason':''},{'reason':' \n\t '},{'reason':'x'*1001},
                                 {'reason':'Valid','reviewed_by_user_id':str(uuid4())}])
def test_invalid_reject_or_forged_review_fields_do_not_mutate(api,body):
    client,session,chief,_,headers=api
    work,_,request=pending(api)
    result=client.post(f"{ROOT}/completion-requests/{request['id']}/reject",headers=headers(chief),json=body)
    assert result.status_code==422
    assert session.get(TechnicalWork,UUID(work)).status=='awaitingCompletionApproval'
    assert session.get(TechnicalWorkCompletionRequest,UUID(request['id'])).decision=='pending'


def test_invalid_state_and_service_reason_validation_and_protected_team_grant(api):
    client,session,chief,_,headers=api
    work,team_id,request=pending(api)
    assert client.post(f'{ROOT}/completion-requests/{request["id"]}/approve',headers=headers(chief),json={'reviewed_at':'fake'}).status_code==422
    assert client.post(f'/api/v1/teams/{team_id}/permissions',headers=headers(chief),json={'permissions':['reviewTechnicalWorkCompletion']}).status_code==403
    from fastapi import HTTPException
    with pytest.raises(HTTPException) as invalid:
        review_completion(session,chief,UUID(request['id']),rejection_reason='  ')
    assert invalid.value.status_code==422
    session.rollback()
    session.get(TechnicalWork,UUID(work)).status='onHold'
    session.commit()
    result=client.post(f"{ROOT}/completion-requests/{request['id']}/approve",headers=headers(chief),json={})
    assert result.status_code==409 and result.json()['detail']['code']=='technical_work_completion_review_invalid_state'
    assert session.get(TechnicalWorkCompletionRequest,UUID(request['id'])).decision=='pending'
