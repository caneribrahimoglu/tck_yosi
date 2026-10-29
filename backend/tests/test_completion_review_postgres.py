import os
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.models.technical_work import TechnicalWork
from app.models.technical_work_completion import TechnicalWorkCompletionRequest
from app.models.user import User
from app.schemas.technical_work_completion import CompletionInput
from app.services.technical_work_completion import request_completion,review_completion
from tests.test_technical_work_postgres import postgres
from tests.test_technical_work_execution_postgres import race
from tests.test_completion_request_postgres import prepared

pytestmark=pytest.mark.skipif(os.environ.get('TCK_TEST_POSTGRES')!='1',reason='Opt-in PostgreSQL test')


@pytest.mark.parametrize('decisions',[('approve','approve'),('reject','reject'),('approve','reject')])
def test_postgres_two_reviewers_have_one_terminal_decision(postgres,decisions):
    sessions,chiefs,engineer,_,work=prepared(postgres)
    with sessions.begin() as session:
        request=request_completion(session,session.get(User,engineer),work,
            CompletionInput(submission_id=uuid4(),summary='Done',expected_revision=2))[1].id
    def decide(action):
        def run(session,actor):
            return review_completion(session,actor,request,rejection_reason=None if action=='approve' else 'Needs correction')[1].decision
        return run
    results=race(sessions,[(chiefs[i],decide(action)) for i,action in enumerate(decisions)])
    assert [r[0] for r in results].count('ok')==1
    assert ('error','technical_work_completion_already_decided') in results
    with sessions() as session:
        history=session.scalars(select(TechnicalWorkCompletionRequest)).all()
        assert len(history)==1
        current=session.get(TechnicalWork,work)
        winner=next(i for i,result in enumerate(results) if result[0]=='ok')
        assert history[0].reviewed_by_user_id==chiefs[winner] and history[0].reviewed_at is not None
        assert current.revision==4
        assert current.status==('completed' if history[0].decision=='approved' else 'inProgress')
        if history[0].decision=='approved':
            assert current.completed_at==history[0].reviewed_at
