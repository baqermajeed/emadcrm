from math import ceil
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status

from app.dependencies import Database, require_roles
from app.schemas.common import Paginated
from app.schemas.deal import DealCreate, DealOut, DealUpdate
from app.services.deal_service import DealService
from app.utils.enums import UserRole

router = APIRouter(prefix="/deals", tags=["Deals"])

AccessDep = Annotated[
    dict,
    Depends(
        require_roles(
            UserRole.RECEPTION,
            UserRole.SALES,
            UserRole.MANAGER,
        )
    ),
]


@router.post("", response_model=DealOut, status_code=status.HTTP_201_CREATED)
async def create_deal(body: DealCreate, db: Database, current_user: AccessDep):
    return await DealService(db).create(body, current_user)


@router.get("", response_model=Paginated[DealOut])
async def list_deals(
    db: Database,
    current_user: AccessDep,
    customer_id: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
):
    sales_id = current_user["id"] if current_user["role"] == UserRole.SALES.value else None
    items, total = await DealService(db).list_deals(
        customer_id=customer_id,
        sales_employee_id=sales_id,
        page=page,
        page_size=page_size,
    )
    return Paginated(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        pages=ceil(total / page_size) if page_size else 0,
    )


@router.get("/{deal_id}", response_model=DealOut)
async def get_deal(deal_id: str, db: Database, _: AccessDep):
    return await DealService(db).get(deal_id)


@router.patch("/{deal_id}", response_model=DealOut)
async def update_deal(deal_id: str, body: DealUpdate, db: Database, current_user: AccessDep):
    return await DealService(db).update(deal_id, body, current_user)
