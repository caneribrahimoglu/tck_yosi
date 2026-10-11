from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, SecretStr, field_validator

from app.models.permission import AppPermission
from app.models.user import UserRole


class UserCreate(BaseModel):
    full_name: str = Field(min_length=2, max_length=120)
    username: str = Field(min_length=3, max_length=50, pattern=r"^[a-zA-Z0-9_.-]+$")
    role: UserRole
    temporary_password: SecretStr

    @field_validator("full_name", "username", mode="before")
    @classmethod
    def trim(cls, value: str) -> str:
        return value.strip()


class PermissionsInput(BaseModel):
    permissions: list[AppPermission]


class ActiveInput(BaseModel):
    is_active: bool


class PasswordResetInput(BaseModel):
    temporary_password: SecretStr


class TeamInput(BaseModel):
    name: str = Field(min_length=3, max_length=120)
    description: str = Field(default="", max_length=2000)

    @field_validator("name", "description", mode="before")
    @classmethod
    def trim(cls, value: str) -> str:
        return value.strip()


class TeamResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    name: str
    description: str
    is_active: bool
    is_archived: bool
    permissions: list[AppPermission]


class MemberInput(BaseModel):
    user_id: UUID


class MembershipResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    team_id: UUID
    user_id: UUID
    is_active: bool


class DirectoryUserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    full_name: str
    username: str
    role: UserRole
    is_active: bool
    must_change_password: bool
