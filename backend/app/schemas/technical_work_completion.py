from datetime import datetime, timezone
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.technical_work import WorkResponse
from app.schemas.technical_work_execution import TransitionInput


class CompletionInput(TransitionInput):
    submission_id: UUID
    summary: str = Field(min_length=1, max_length=1000)

    @field_validator("summary", mode="before")
    @classmethod
    def trim(cls, value):
        return value.strip() if isinstance(value, str) else value


class CompletionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    work_id: UUID
    requested_by_user_id: UUID
    summary: str
    requested_at: datetime
    decision: Literal["pending", "approved", "rejected"]
    reviewed_by_user_id: UUID | None
    reviewed_at: datetime | None
    rejection_reason: str | None

    @field_validator("requested_at", "reviewed_at")
    @classmethod
    def utc(cls, value):
        return value.replace(tzinfo=timezone.utc) if value is not None and value.tzinfo is None else value


class CompletionSubmissionResponse(BaseModel):
    work: WorkResponse
    request: CompletionResponse


class CompletionReviewItem(BaseModel):
    work: WorkResponse
    request: CompletionResponse


class ApprovalInput(BaseModel):
    model_config = ConfigDict(extra="forbid")


class RejectionInput(ApprovalInput):
    reason: str = Field(min_length=1, max_length=1000)

    @field_validator("reason", mode="before")
    @classmethod
    def trim(cls, value):
        return value.strip() if isinstance(value, str) else value
