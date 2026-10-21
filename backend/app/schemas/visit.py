from datetime import datetime

from pydantic import Field

from app.schemas.common import ORMModel


class VisitCreate(ORMModel):
    customer_id: str
    visit_date: datetime | None = None
    notes: str | None = Field(default=None, max_length=1000)
    sales_employee_id: str | None = None


class VisitUpdate(ORMModel):
    notes: str | None = Field(default=None, max_length=1000)


class VisitOut(ORMModel):
    id: str
    customer_id: str
    visit_date: datetime
    notes: str | None = None
    sales_employee_id: str | None = None
    sales_employee_name: str | None = None
    recorded_by: str | None = None
    recorded_by_name: str | None = None
    created_at: datetime
