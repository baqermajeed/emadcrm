from datetime import datetime

from pydantic import Field

from app.schemas.common import ORMModel


class CustomerSalesNoteCreate(ORMModel):
    note: str = Field(min_length=1, max_length=1000)


class CustomerSalesNoteOut(ORMModel):
    id: str
    customer_id: str
    sales_employee_id: str
    note: str
    created_at: datetime
    sales_employee_name: str | None = None
    sales_employee_avatar_url: str | None = None
