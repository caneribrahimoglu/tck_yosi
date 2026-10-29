import os
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.models.team import Team
from app.models.technical_work import TechnicalWork
from app.models.technical_work_completion import TechnicalWorkCompletionRequest
from app.schemas.technical_work_completion import CompletionInput
from app.schemas.technical_work_execution import HoldInput
from app.services.technical_work_completion import request_completion
from app.services.technical_work_execution import hold_work
from tests.test_technical_work_postgres import postgres
from tests.test_technical_work_execution_postgres import race, setup_work

pytestmark = pytest.mark.skipif(os.environ.get('TCK_TEST_POSTGRES') != '1', reason='Opt-in PostgreSQL test')


def prepared(postgres):
    values = setup_work(postgres,started=True)
    sessions, _, _, team_id, _ = values
    with sessions.begin() as session:
        group = session.get(Team,team_id)
        group.permissions = [*group.permissions,'requestTechnicalWorkCompletion']
    return values


@pytest.mark.parametrize('same_key', [False,True])
def test_postgres_one_pending_request_even_on_two_devices(postgres,same_key):
    sessions, chiefs, engineer, _, work = prepared(postgres)
    key = uuid4()
    def submit(session,actor):
        data = CompletionInput(submission_id=key if same_key else uuid4(),summary='Done',expected_revision=2)
        return request_completion(session,actor,work,data)[1].id
    actors = [engineer,engineer] if same_key else [engineer,chiefs[1]]
    results = race(sessions,[(actor,submit) for actor in actors])
    if same_key:
        assert results[0] == results[1] and results[0][0] == 'ok'
    else:
        assert [r[0] for r in results].count('ok') == 1
        assert ('error','technical_work_completion_invalid_state') in results
    with sessions() as session:
        assert len(session.scalars(select(TechnicalWorkCompletionRequest)).all()) == 1
        current = session.get(TechnicalWork,work)
        assert current.status == 'awaitingCompletionApproval' and current.revision == 3


def test_postgres_hold_vs_completion_only_one_transition(postgres):
    sessions, chiefs, engineer, _, work = prepared(postgres)
    def completion(session,actor):
        return request_completion(session,actor,work,CompletionInput(submission_id=uuid4(),summary='Done',expected_revision=2))[1].id
    def hold(session,actor):
        return hold_work(session,actor,work,HoldInput(reason='Pause',expected_revision=2))[1].id
    results = race(sessions,[(engineer,completion),(chiefs[1],hold)])
    assert [r[0] for r in results].count('ok') == 1
    with sessions() as session:
        current = session.get(TechnicalWork,work)
        assert current.revision == 3
        requests = session.scalars(select(TechnicalWorkCompletionRequest)).all()
        assert len(requests) == (1 if current.status == 'awaitingCompletionApproval' else 0)
