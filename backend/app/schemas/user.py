import re
from datetime import datetime

from pydantic import Field, field_validator

from app.schemas.common import ORMModel
from app.utils.enums import UserRole
from app.utils.validators import (
    validate_optional_iraq_phone,
    validate_optional_person_name,
    validate_person_name,
)

_USERNAME_RE = re.compile(r"^[a-zA-Z0-9._-]+$")


def _validate_username(value: str) -> str:
    cleaned = value.strip()
    if len(cleaned) < 3:
        raise ValueError("اسم الدخول يجب أن يكون ٣ أحرف على الأقل")
    if len(cleaned) > 64:
        raise ValueError("اسم الدخول طويل جداً")
    if not _USERNAME_RE.fullmatch(cleaned):
        raise ValueError("اسم الدخول يجب أن يكون أحرف إنجليزية وأرقام فقط")
    return cleaned


class UserCreate(ORMModel):
    username: str = Field(min_length=3, max_length=64)
    password: str = Field(min_length=4, max_length=128)
    full_name: str = Field(min_length=2, max_length=120)
    role: UserRole
    phone: str | None = Field(default=None, max_length=11)
    is_active: bool = True

    @field_validator("username")
    @classmethod
    def _username(cls, v: str) -> str:
        return _validate_username(v)

    @field_validator("full_name")
    @classmethod
    def _name(cls, v: str) -> str:
        return validate_person_name(v)

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str | None) -> str | None:
        return validate_optional_iraq_phone(v)


class UserUpdate(ORMModel):
    username: str | None = Field(default=None, min_length=3, max_length=64)
    full_name: str | None = Field(default=None, min_length=2, max_length=120)
    phone: str | None = Field(default=None, max_length=11)
    role: UserRole | None = None
    password: str | None = Field(default=None, min_length=4, max_length=128)
    is_active: bool | None = None
    clear_avatar: bool | None = None

    @field_validator("username")
    @classmethod
    def _username(cls, v: str | None) -> str | None:
        if v is None:
            return None
        return _validate_username(v)

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
    avatar_url: str | None = None
    is_active: bool
    created_at: datetime
