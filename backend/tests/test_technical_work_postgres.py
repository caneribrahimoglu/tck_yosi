"""Opt-in transaction/race checks in an isolated disposable PostgreSQL schema.

Run with TCK_TEST_POSTGRES=1. Existing application tables/data are never used.
"""
import os
import re
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import select, text
from sqlalchemy.orm import sessionmaker

from app.api.routes.management import archive_team
from app.db.base import Base
from app.db.session import engine
from app.models.permission import INITIAL_CHIEF_PERMISSIONS
from app.models.team import Team
from app.models.technical_work import TechnicalWork, TechnicalWorkAssignment
from app.models.user import User, UserRole
from app.schemas.technical_work import AssignmentInput, FieldReportInput
from app.services.technical_work import assign_work, create_report

pytestmark = pytest.mark.skipif(os.environ.get('TCK_TEST_POSTGRES') != '1', reason='Opt-in local PostgreSQL race test')


@pytest.fixture
def postgres():
    schema = 'tck_work_test_' + uuid4().hex
    assert re.fullmatch(r'tck_work_test_[0-9a-f]{32}', schema)
    with engine.begin() as connection:
        connection.execute(text(f'CREATE SCHEMA "{schema}"'))
    isolated = engine.execution_options(schema_translate_map={None: schema})
    sessions = sessionmaker(bind=isolated, expire_on_commit=False)
    try:
        Base.metadata.create_all(isolated)
        with sessions.begin() as session:
            chiefs = [User(full_name=f'Test Chief {i}',username=f'chief{i}',role=UserRole.chief,
                password_hash='unused-test-only',is_active=True,must_change_password=False,
                permissions=list(INITIAL_CHIEF_PERMISSIONS)) for i in range(2)]
            engineer = User(full_name='Test Engineer',username='engineer',role=UserRole.engineer,
                password_hash='unused-test-only',is_active=True,must_change_password=False,permissions=[])
            team = Team(name='Test Team',normalized_name='test team',description='',permissions=[],is_active=True,is_archived=False)
            session.add_all([*chiefs, engineer, team])
            session.flush()
            data = FieldReportInput(submission_id=uuid4(),title='Test Work',description='D',location='L',category='other')
            work = create_report(session, chiefs[0], data)
            ids = ([chief.id for chief in chiefs], engineer.id, team.id, work.id)
        yield sessions, ids
    finally:
        # Only the generated, explicitly validated test-owned schema is removed.
        assert re.fullmatch(r'tck_work_test_[0-9a-f]{32}', schema)
        with engine.begin() as connection:
            connection.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))


def test_postgres_simultaneous_assignment_only_one_revision_wins(postgres):
    sessions, (chiefs, engineer, _, work) = postgres
    barrier = Barrier(2)
    def operation(actor_id):
        try:
            with sessions.begin() as session:
                actor = session.get(User, actor_id)
                barrier.wait(timeout=10)
                result = assign_work(session, actor, work, AssignmentInput(priority='high',assigned_to_user_id=engineer,expected_revision=0))
                return result.revision
        except HTTPException as error:
            return error.detail['code']
    with ThreadPoolExecutor(max_workers=2) as pool:
        result = list(pool.map(operation, chiefs))
    assert sorted(map(str,result)) == ['1','work_revision_conflict']
    with sessions() as session:
        assert session.get(TechnicalWork, work).revision == 1
        assert len(session.scalars(select(TechnicalWorkAssignment)).all()) == 1


def test_postgres_duplicate_report_retry_creates_one_record(postgres):
    sessions, (chiefs, _, _, _) = postgres
    data = FieldReportInput(submission_id=uuid4(),title='Parallel Report',description='D',location='L',category='other')
    barrier = Barrier(2)
    def operation(_):
        with sessions.begin() as session:
            actor = session.get(User, chiefs[0])
            barrier.wait(timeout=10)
            return create_report(session, actor, data).id
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(operation, range(2)))
    assert results[0] == results[1]
    with sessions() as session:
        assert len(session.scalars(select(TechnicalWork).where(TechnicalWork.submission_id==data.submission_id)).all()) == 1


def test_postgres_archive_assignment_race_cannot_leave_open_archived_target(postgres):
    sessions, (chiefs, _, team, work) = postgres
    barrier = Barrier(2)
    def assign():
        try:
            with sessions.begin() as session:
                actor = session.get(User,chiefs[0])
                barrier.wait(timeout=10)
                assign_work(session,actor,work,AssignmentInput(priority='normal',assigned_to_team_id=team,expected_revision=0))
                return 'assigned'
        except HTTPException as error:
            return error.detail['code']
    def archive():
        try:
            with sessions() as session:
                actor = session.get(User,chiefs[1])
                barrier.wait(timeout=10)
                archive_team(team,session,actor)
                return 'archived'
        except HTTPException as error:
            return error.detail['code']
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(assign),pool.submit(archive)]
        results = [future.result(timeout=20) for future in futures]
    assert results in [['assigned','team_has_open_work'], ['assignment_target_not_available','archived']]
    with sessions() as session:
        target = session.get(Team,team)
        current = session.get(TechnicalWork,work)
        assert not (target.is_archived and current.assigned_to_team_id==team and current.status=='assigned')
