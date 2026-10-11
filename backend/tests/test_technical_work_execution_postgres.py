"""Execution race checks use only the disposable schema fixture, never live data."""
import os
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import select

from app.models.team import Team, TeamMembership
from app.models.technical_work import TechnicalWork
from app.models.technical_work_execution import TechnicalWorkHoldRecord, TechnicalWorkProgressNote
from app.models.user import User
from app.schemas.technical_work import AssignmentInput
from app.schemas.technical_work_execution import HoldInput, ProgressInput, TransitionInput
from app.services.technical_work import assign_work
from app.services.technical_work_execution import start_work, add_progress, hold_work, resume_work
from tests.test_technical_work_execution_api import PERMISSIONS
from tests.test_technical_work_postgres import postgres

pytestmark = pytest.mark.skipif(os.environ.get('TCK_TEST_POSTGRES') != '1', reason='Opt-in PostgreSQL test')


def setup_work(postgres, *, started=False, held=False):
    sessions, (chiefs, engineer, team_id, work_id) = postgres
    with sessions.begin() as session:
        team = session.get(Team, team_id)
        team.permissions = PERMISSIONS[:]
        # Different actor rows; concurrency is serialized by shared team/work locks.
        session.add_all([TeamMembership(team_id=team_id, user_id=user_id, is_active=True)
                         for user_id in [engineer, chiefs[1]]])
        assign_work(session, session.get(User, chiefs[0]), work_id,
                    AssignmentInput(priority='normal', assigned_to_team_id=team_id, expected_revision=0))
        if started:
            start_work(session, session.get(User, engineer), work_id, TransitionInput(expected_revision=1))
        if held:
            hold_work(session, session.get(User, engineer), work_id, HoldInput(expected_revision=2, reason='First hold'))
    return sessions, chiefs, engineer, team_id, work_id


def race(sessions, operations):
    barrier = Barrier(len(operations))
    def run(item):
        actor_id, operation = item
        try:
            with sessions.begin() as session:
                actor = session.get(User, actor_id)
                barrier.wait(timeout=10)
                result = operation(session, actor)
                return ('ok', result)
        except HTTPException as error:
            return ('error', error.detail['code'])
    with ThreadPoolExecutor(max_workers=len(operations)) as pool:
        return list(pool.map(run, operations))


def test_postgres_two_authorized_starts_preserve_one_starter(postgres):
    sessions, chiefs, engineer, team, work = setup_work(postgres)
    def start(session, actor):
        return start_work(session, actor, work, TransitionInput(expected_revision=1)).started_by_user_id
    results = race(sessions, [(engineer, start), (chiefs[1], start)])
    assert [item[0] for item in results].count('ok') == 1
    assert ('error', 'technical_work_already_started') in results
    with sessions() as session:
        current = session.get(TechnicalWork, work)
        assert current.revision == 2 and current.assigned_to_team_id == team
        assert current.started_by_user_id == next(item[1] for item in results if item[0] == 'ok')


def test_postgres_unauthorized_start_does_not_claim_work_or_leak_state(postgres):
    sessions, chiefs, engineer, _, work = setup_work(postgres)
    def start(session, actor):
        return start_work(session, actor, work, TransitionInput(expected_revision=1)).started_by_user_id
    results = race(sessions, [(chiefs[0], start), (engineer, start)])
    assert results == [('error', 'technical_work_start_not_allowed'), ('ok', engineer)]


@pytest.mark.parametrize('operations,held', [('hold/hold', False), ('resume/resume', True), ('resume/hold', True)])
def test_postgres_hold_resume_races_have_one_transition(postgres, operations, held):
    sessions, chiefs, engineer, team, work = setup_work(postgres, started=True, held=held)
    revision = 3 if held else 2
    def operation(name):
        def perform(session, actor):
            if name == 'hold':
                return hold_work(session, actor, work, HoldInput(expected_revision=revision, reason='Racing hold'))[1].id
            return resume_work(session, actor, work, TransitionInput(expected_revision=revision))[1].id
        return perform
    first, second = operations.split('/')
    results = race(sessions, [(engineer, operation(first)), (chiefs[1], operation(second))])
    assert [item[0] for item in results].count('ok') == 1
    assert next(item[1] for item in results if item[0] == 'error') in (
        'technical_work_hold_invalid_state', 'technical_work_hold_transition_conflict')
    with sessions() as session:
        current = session.get(TechnicalWork, work)
        assert current.revision == revision + 1 and current.assigned_to_team_id == team
        history = session.scalars(select(TechnicalWorkHoldRecord).where(TechnicalWorkHoldRecord.work_id == work)).all()
        assert len(history) == 1
        assert (history[0].resumed_at is not None) == held


def test_postgres_duplicate_progress_retry_has_one_server_record(postgres):
    sessions, _, engineer, _, work = setup_work(postgres, started=True)
    data = ProgressInput(submission_id=uuid4(), content='Same operation')
    def submit(session, actor):
        return add_progress(session, actor, work, data).id
    results = race(sessions, [(engineer, submit), (engineer, submit)])
    assert results[0] == results[1] and results[0][0] == 'ok'
    with sessions() as session:
        assert len(session.scalars(select(TechnicalWorkProgressNote)).all()) == 1


def test_postgres_progress_hold_race_never_adds_note_after_hold(postgres):
    sessions, chiefs, engineer, _, work = setup_work(postgres, started=True)
    def hold(session, actor):
        return hold_work(session, actor, work, HoldInput(expected_revision=2, reason='Stop'))[1].id
    def progress(session, actor):
        return add_progress(session, actor, work, ProgressInput(submission_id=uuid4(), content='Racing note')).id
    results = race(sessions, [(engineer, hold), (chiefs[1], progress)])
    assert results[0][0] == 'ok'
    with sessions() as session:
        assert session.get(TechnicalWork, work).status == 'onHold'
        notes = session.scalars(select(TechnicalWorkProgressNote)).all()
        holds = session.scalars(select(TechnicalWorkHoldRecord)).all()
        if results[1][0] == 'ok':
            assert len(notes) == 1 and notes[0].created_at <= holds[0].held_at
        else:
            assert results[1][1] == 'technical_work_progress_invalid_state' and notes == []
