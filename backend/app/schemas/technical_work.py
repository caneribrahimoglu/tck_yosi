from datetime import datetime, timezone
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.technical_work import WorkCategory, WorkPriority, WorkStatus


class FieldReportInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    submission_id: UUID
    title: str = Field(min_length=1, max_length=100)
    description: str = Field(min_length=1, max_length=1000)
    location: str = Field(min_length=1, max_length=150)
    category: WorkCategory

    @field_validator("title", "description", "location", mode="before")
    @classmethod
    def trim(cls, value: str) -> str:
        return value.strip() if isinstance(value, str) else value


class AssignmentInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    priority: WorkPriority
    assigned_to_user_id: UUID | None = None
    assigned_to_team_id: UUID | None = None
    expected_revision: int = Field(ge=0)

    @model_validator(mode="after")
    def exactly_one_target(self):
        if (self.assigned_to_user_id is None) == (self.assigned_to_team_id is None):
            raise ValueError("Exactly one assignment target is required.")
        return self


class WorkResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    title: str
    description: str
    location: str
    category: WorkCategory
    priority: WorkPriority
    status: WorkStatus
    created_by_user_id: UUID
    assigned_to_user_id: UUID | None
    assigned_to_team_id: UUID | None
    created_at: datetime
    revision: int
    planned_at: datetime | None
    completed_at: datetime | None
    started_by_user_id: UUID | None
    started_at: datetime | None

    @field_validator('created_at', 'planned_at', 'completed_at', 'started_at')
    @classmethod
    def utc_timestamp(cls, value):
        # SQLite test adapter drops tzinfo; stored timestamps are always UTC.
        return value.replace(tzinfo=timezone.utc) if value is not None and value.tzinfo is None else value


class AssignmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    work_id: UUID
    assigned_by_user_id: UUID
    assigned_at: datetime
    assigned_to_user_id: UUID | None
    assigned_to_team_id: UUID | None
    previous_user_id: UUID | None
    previous_team_id: UUID | None
    priority: WorkPriority
    revision: int

    @field_validator('assigned_at')
    @classmethod
    def utc_timestamp(cls, value):
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value
