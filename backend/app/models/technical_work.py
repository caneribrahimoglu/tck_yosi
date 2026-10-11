from datetime import datetime
from enum import Enum
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class WorkCategory(str, Enum):
    roadSurface = "roadSurface"
    trafficAccident = "trafficAccident"
    lighting = "lighting"
    trafficSign = "trafficSign"
    roadMarking = "roadMarking"
    barrier = "barrier"
    drainage = "drainage"
    bridgeAndViaduct = "bridgeAndViaduct"
    tunnel = "tunnel"
    landslide = "landslide"
    building = "building"
    electricalSystem = "electricalSystem"
    vehicle = "vehicle"
    workMachine = "workMachine"
    other = "other"


class WorkPriority(str, Enum):
    low = "low"
    normal = "normal"
    high = "high"
    critical = "critical"


class WorkStatus(str, Enum):
    reported = "reported"
    awaitingInspection = "awaitingInspection"
    assigned = "assigned"
    inProgress = "inProgress"
    awaitingCompletionApproval = "awaitingCompletionApproval"
    onHold = "onHold"
    completed = "completed"
    cancelled = "cancelled"


class TechnicalWork(Base):
    __tablename__ = "technical_works"
    __table_args__ = (
        UniqueConstraint("created_by_user_id", "submission_id", name="uq_work_submission"),
        CheckConstraint("assigned_to_user_id IS NULL OR assigned_to_team_id IS NULL", name="ck_work_single_target"),
        CheckConstraint("status != 'assigned' OR assigned_to_user_id IS NOT NULL OR assigned_to_team_id IS NOT NULL",
                        name="ck_assigned_work_target"),
        CheckConstraint("revision >= 0", name="ck_work_revision"),
        CheckConstraint("priority IN ('low','normal','high','critical')", name="ck_work_priority"),
        CheckConstraint("status IN ('reported','awaitingInspection','assigned','inProgress',"
                        "'awaitingCompletionApproval','onHold','completed','cancelled')", name="ck_work_status"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    submission_id: Mapped[UUID] = mapped_column(nullable=False)
    title: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str] = mapped_column(String(1000), nullable=False)
    location: Mapped[str] = mapped_column(String(150), nullable=False)
    category: Mapped[str] = mapped_column(String(32), nullable=False)
    priority: Mapped[str] = mapped_column(String(16), nullable=False, default=WorkPriority.normal.value)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default=WorkStatus.reported.value)
    created_by_user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    assigned_to_user_id: Mapped[UUID | None] = mapped_column(ForeignKey("users.id"), index=True)
    assigned_to_team_id: Mapped[UUID | None] = mapped_column(ForeignKey("teams.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    planned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    started_by_user_id: Mapped[UUID | None] = mapped_column(ForeignKey("users.id"))
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class TechnicalWorkAssignment(Base):
    """Append-only assignment audit; business lifecycle history comes next."""
    __tablename__ = "technical_work_assignments"
    __table_args__ = (UniqueConstraint("work_id", "revision", name="uq_assignment_revision"),)

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    work_id: Mapped[UUID] = mapped_column(ForeignKey("technical_works.id"), nullable=False, index=True)
    assigned_by_user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    assigned_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    assigned_to_user_id: Mapped[UUID | None] = mapped_column(ForeignKey("users.id"))
    assigned_to_team_id: Mapped[UUID | None] = mapped_column(ForeignKey("teams.id"))
    previous_user_id: Mapped[UUID | None] = mapped_column(ForeignKey("users.id"))
    previous_team_id: Mapped[UUID | None] = mapped_column(ForeignKey("teams.id"))
    priority: Mapped[str] = mapped_column(String(16), nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False)
