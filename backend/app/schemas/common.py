from datetime import datetime
from typing import Generic, TypeVar

from pydantic import BaseModel, ConfigDict, Field


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


T = TypeVar("T")


class MessageOut(ORMModel):
    message: str


class Paginated(ORMModel, Generic[T]):
    items: list[T]
    total: int
    page: int = Field(ge=1)
    page_size: int = Field(ge=1, le=100)
    pages: int


class TimestampMixin(ORMModel):
    created_at: datetime
    updated_at: datetime | None = None
