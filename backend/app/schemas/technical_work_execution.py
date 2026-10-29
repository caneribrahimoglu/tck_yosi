from datetime import datetime, timezone
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.technical_work import WorkResponse


class TransitionInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    expected_revision: int = Field(ge=0)


class HoldInput(TransitionInput):
    reason: str = Field(min_length=1, max_length=1000)

    @field_validator("reason", mode="before")
    @classmethod
    def trim(cls, value):
        return value.strip() if isinstance(value, str) else value


class ProgressInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    submission_id: UUID
    content: str = Field(min_length=1, max_length=1000)

    @field_validator("content", mode="before")
    @classmethod
    def trim(cls, value):
        return value.strip() if isinstance(value, str) else value


class ProgressResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    work_id: UUID
    author_user_id: UUID
    content: str
    created_at: datetime

    @field_validator("created_at")
    @classmethod
    def utc(cls, value):
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


class HoldResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    work_id: UUID
    held_by_user_id: UUID
    held_at: datetime
    reason: str
    resumed_by_user_id: UUID | None
    resumed_at: datetime | None

    @field_validator("held_at", "resumed_at")
    @classmethod
    def utc(cls, value):
        return value.replace(tzinfo=timezone.utc) if value is not None and value.tzinfo is None else value


class HoldTransitionResponse(BaseModel):
    work: WorkResponse
    record: HoldResponse


class ExecutionCapabilities(BaseModel):
    can_start: bool
    can_add_progress: bool
    can_pause: bool
    can_resume: bool
    can_request_completion: bool
