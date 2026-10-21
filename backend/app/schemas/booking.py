from datetime import datetime

from pydantic import Field, field_validator

from app.schemas.common import ORMModel
from app.utils.enums import BookingSource, BookingStatus, HowKnewCenter, VisitType
from app.utils.validators import (
    validate_iraq_phone,
    validate_optional_iraq_phone,
    validate_optional_person_name,
    validate_person_name,
)


class BookingCreate(ORMModel):
    name: str = Field(min_length=2, max_length=120)
    phone: str = Field(min_length=11, max_length=11)
    governorate: str = Field(min_length=2, max_length=80)
    source: BookingSource
    visit_date: datetime
    notes: str | None = Field(default=None, max_length=1000)

    @field_validator("name")
    @classmethod
    def _name(cls, v: str) -> str:
        return validate_person_name(v)

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str) -> str:
        return validate_iraq_phone(v)


class BookingUpdate(ORMModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    phone: str | None = Field(default=None, min_length=11, max_length=11)
    governorate: str | None = Field(default=None, min_length=2, max_length=80)
    source: BookingSource | None = None
    visit_date: datetime | None = None
    notes: str | None = Field(default=None, max_length=1000)
    status: BookingStatus | None = None

    @field_validator("name")
    @classmethod
    def _name(cls, v: str | None) -> str | None:
        return validate_optional_person_name(v)

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str | None) -> str | None:
        return validate_optional_iraq_phone(v)


class BookingApprove(ORMModel):
    sales_employee_id: str
    visit_type: VisitType | None = None
    existing_customer_id: str | None = None
    profession: str | None = Field(default=None, max_length=120)
    address: str | None = Field(default=None, max_length=250)
    how_knew: HowKnewCenter | None = None
    referral_buyer_name: str | None = Field(default=None, max_length=120)
    notes: str | None = Field(default=None, max_length=1000)

    @field_validator("referral_buyer_name")
    @classmethod
    def _referral(cls, v: str | None) -> str | None:
        return validate_optional_person_name(v)


class BookingOut(ORMModel):
    id: str
    name: str
    phone: str
    governorate: str
    source: BookingSource
    visit_date: datetime
    notes: str | None = None
    status: BookingStatus
    call_center_id: str
    call_center_name: str | None = None
    call_center_avatar_url: str | None = None
    customer_id: str | None = None
    visit_type: VisitType | None = None
    approved_by: str | None = None
    approved_at: datetime | None = None
    created_at: datetime
    updated_at: datetime | None = None
