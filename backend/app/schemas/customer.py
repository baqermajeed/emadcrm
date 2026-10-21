from datetime import datetime

from pydantic import Field, field_validator

from app.schemas.common import ORMModel
from app.utils.enums import CustomerGender, CustomerStatus, HowKnewCenter
from app.utils.validators import (
    validate_iraq_phone,
    validate_optional_iraq_phone,
    validate_optional_person_name,
    validate_person_name,
)


class CustomerCreateFromBooking(ORMModel):
    booking_id: str
    sales_employee_id: str
    name: str | None = Field(default=None, min_length=2, max_length=120)
    profession: str | None = Field(default=None, max_length=120)
    address: str | None = Field(default=None, max_length=250)
    phone: str | None = Field(default=None, min_length=11, max_length=11)
    gender: CustomerGender | None = None
    how_knew: HowKnewCenter | None = None
    referral_buyer_name: str | None = Field(default=None, max_length=120)
    notes: str | None = Field(default=None, max_length=1000)

    @field_validator("name")
    @classmethod
    def _name(cls, v: str | None) -> str | None:
        return validate_optional_person_name(v)

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str | None) -> str | None:
        return validate_optional_iraq_phone(v)

    @field_validator("referral_buyer_name")
    @classmethod
    def _referral(cls, v: str | None) -> str | None:
        return validate_optional_person_name(v)


class CustomerCreate(ORMModel):
    name: str = Field(min_length=2, max_length=120)
    phone: str = Field(min_length=11, max_length=11)
    email: str | None = Field(default=None, max_length=120)
    profession: str | None = Field(default=None, max_length=120)
    address: str | None = Field(default=None, max_length=250)
    gender: CustomerGender | None = CustomerGender.MALE
    how_knew: HowKnewCenter | None = None
    referral_buyer_name: str | None = Field(default=None, max_length=120)
    sales_employee_id: str | None = None
    notes: str | None = Field(default=None, max_length=1000)
    status: CustomerStatus | None = CustomerStatus.POTENTIAL

    @field_validator("name")
    @classmethod
    def _name(cls, v: str) -> str:
        return validate_person_name(v)

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str) -> str:
        return validate_iraq_phone(v)

    @field_validator("referral_buyer_name")
    @classmethod
    def _referral(cls, v: str | None) -> str | None:
        return validate_optional_person_name(v)


class CustomerUpdate(ORMModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    profession: str | None = Field(default=None, max_length=120)
    address: str | None = Field(default=None, max_length=250)
    phone: str | None = Field(default=None, min_length=11, max_length=11)
    email: str | None = Field(default=None, max_length=120)
    gender: CustomerGender | None = None
    how_knew: HowKnewCenter | None = None
    referral_buyer_name: str | None = Field(default=None, max_length=120)
    sales_employee_id: str | None = None
    notes: str | None = Field(default=None, max_length=1000)
    status: CustomerStatus | None = None

    @field_validator("name")
    @classmethod
    def _name(cls, v: str | None) -> str | None:
        return validate_optional_person_name(v)

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str | None) -> str | None:
        return validate_optional_iraq_phone(v)

    @field_validator("referral_buyer_name")
    @classmethod
    def _referral(cls, v: str | None) -> str | None:
        return validate_optional_person_name(v)


class DocumentOut(ORMModel):
    id: str
    filename: str
    original_name: str
    content_type: str
    url: str
    uploaded_at: datetime
    uploaded_by: str | None = None
    notes: str | None = None


class CustomerOut(ORMModel):
    id: str
    name: str
    profession: str | None = None
    address: str | None = None
    phone: str
    email: str | None = None
    gender: CustomerGender | None = None
    call_center_id: str | None = None
    call_center_name: str | None = None
    call_center_avatar_url: str | None = None
    how_knew: HowKnewCenter | None = None
    referral_buyer_name: str | None = None
    sales_employee_id: str | None = None
    sales_employee_name: str | None = None
    sales_employee_avatar_url: str | None = None
    notes: str | None = None
    status: CustomerStatus | None = None
    booking_id: str | None = None
    documents: list[DocumentOut] = []
    created_at: datetime
    updated_at: datetime | None = None
