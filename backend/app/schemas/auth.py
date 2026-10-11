from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, SecretStr

from app.models.user import UserRole
from app.models.permission import AppPermission


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=50)
    password: SecretStr


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    full_name: str
    username: str
    email: str | None
    role: UserRole
    is_active: bool
    must_change_password: bool
    permissions: list[AppPermission]


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserResponse


class ChangePasswordRequest(BaseModel):
    current_password: SecretStr
    new_password: SecretStr


class MessageResponse(BaseModel):
    message: str
