from datetime import datetime

from pydantic import EmailStr, Field, field_validator

from app.schemas.common import ORMModel
from app.utils.enums import DealStatus, HouseType, PaymentType
from app.utils.validators import (
    validate_iraq_phone,
    validate_optional_iraq_phone,
    validate_optional_person_name,
    validate_person_name,
)


class DealCreate(ORMModel):
    customer_id: str
    name: str = Field(min_length=2, max_length=120)
    profession: str | None = Field(default=None, max_length=120)
    email: EmailStr | None = None
    phone: str = Field(min_length=11, max_length=11)
    house_type: HouseType
    house_area: float | None = Field(default=None, gt=0)
    residential_block: str | None = Field(default=None, max_length=80)
    house_number: str | None = Field(default=None, max_length=40)
    total_price: float = Field(gt=0)
    payment_type: PaymentType
    down_payment: float = Field(ge=0)
    notes: str | None = Field(default=None, max_length=1000)
    sales_employee_id: str | None = None
    sale_date: datetime | None = None

    @field_validator("name")
    @classmethod
    def _name(cls, v: str) -> str:
        return validate_person_name(v)

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str) -> str:
        return validate_iraq_phone(v)


class DealUpdate(ORMModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    profession: str | None = Field(default=None, max_length=120)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, min_length=11, max_length=11)
    house_type: HouseType | None = None
    house_area: float | None = Field(default=None, gt=0)
    residential_block: str | None = Field(default=None, max_length=80)
    house_number: str | None = Field(default=None, max_length=40)
    total_price: float | None = Field(default=None, gt=0)
    payment_type: PaymentType | None = None
    down_payment: float | None = Field(default=None, ge=0)
    notes: str | None = Field(default=None, max_length=1000)
    sales_employee_id: str | None = None
    sale_date: datetime | None = None

    @field_validator("name")
    @classmethod
    def _name(cls, v: str | None) -> str | None:
        return validate_optional_person_name(v)

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str | None) -> str | None:
        return validate_optional_iraq_phone(v)


class DealOut(ORMModel):
    id: str
    customer_id: str
    name: str
    profession: str | None = None
    email: str | None = None
    phone: str
    house_type: HouseType
    house_area: float | None = None
    residential_block: str | None = None
    house_number: str | None = None
    total_price: float
    payment_type: PaymentType
    down_payment: float
    status: DealStatus = DealStatus.COMPLETED
    notes: str | None = None
    sales_employee_id: str
    sales_employee_name: str | None = None
    sales_employee_avatar_url: str | None = None
    sale_date: datetime
    created_at: datetime
