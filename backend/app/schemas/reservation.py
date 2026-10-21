from datetime import datetime

from pydantic import Field, field_validator

from app.schemas.common import ORMModel
from app.utils.enums import PaymentType, ReservationStatus
from app.utils.validators import validate_person_name


class ReservationCreate(ORMModel):
    customer_id: str
    name: str = Field(min_length=2, max_length=120)
    house_area: float = Field(gt=0)
    residential_block: str = Field(min_length=1, max_length=80)
    house_number: str = Field(min_length=1, max_length=40)
    total_price: float = Field(gt=0)
    payment_type: PaymentType
    down_payment: float = Field(ge=0)
    notes: str | None = Field(default=None, max_length=1000)
    sales_employee_id: str | None = None
    reservation_date: datetime | None = None
    completion_deadline: datetime

    @field_validator("name")
    @classmethod
    def _name(cls, v: str) -> str:
        return validate_person_name(v)


class ReservationUpdate(ORMModel):
    status: ReservationStatus | None = None
    notes: str | None = Field(default=None, max_length=1000)
    completion_deadline: datetime | None = None
    down_payment: float | None = Field(default=None, ge=0)


class ReservationOut(ORMModel):
    id: str
    customer_id: str
    name: str
    house_area: float
    residential_block: str
    house_number: str
    total_price: float
    payment_type: PaymentType
    down_payment: float
    notes: str | None = None
    sales_employee_id: str
    sales_employee_name: str | None = None
    reservation_date: datetime
    completion_deadline: datetime
    status: ReservationStatus
    created_at: datetime
    updated_at: datetime | None = None
