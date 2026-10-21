from datetime import datetime

from pydantic import Field, field_validator

from app.schemas.common import ORMModel
from app.utils.enums import UserRole
from app.utils.validators import (
    validate_optional_iraq_phone,
    validate_optional_person_name,
    validate_person_name,
)


class UserCreate(ORMModel):
    username: str = Field(min_length=3, max_length=64)
    password: str = Field(min_length=4, max_length=128)
    full_name: str = Field(min_length=2, max_length=120)
    role: UserRole
    phone: str | None = Field(default=None, max_length=11)
    is_active: bool = True

    @field_validator("full_name")
    @classmethod
    def _name(cls, v: str) -> str:
        return validate_person_name(v)

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str | None) -> str | None:
        return validate_optional_iraq_phone(v)


class UserUpdate(ORMModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=120)
    phone: str | None = Field(default=None, max_length=11)
    role: UserRole | None = None
    password: str | None = Field(default=None, min_length=4, max_length=128)
    is_active: bool | None = None

    @field_validator("full_name")
    @classmethod
    def _name(cls, v: str | None) -> str | None:
        return validate_optional_person_name(v)

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str | None) -> str | None:
        return validate_optional_iraq_phone(v)


class UserOut(ORMModel):
    id: str
    username: str
    full_name: str
    role: UserRole
    phone: str | None = None
    is_active: bool
    created_at: datetime
