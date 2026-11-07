from math import ceil
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status

from app.dependencies import Database, require_roles
from app.schemas.common import Paginated
from app.schemas.visit import VisitCreate, VisitOut, VisitUpdate
from app.services.visit_service import VisitService
from app.utils.enums import UserRole

router = APIRouter(prefix="/visits", tags=["Visits"])

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
CreateDep = Annotated[
    dict,
    Depends(require_roles(UserRole.RECEPTION, UserRole.MANAGER, UserRole.SALES)),
]


@router.post("", response_model=VisitOut, status_code=status.HTTP_201_CREATED)
async def create_visit(body: VisitCreate, db: Database, current_user: CreateDep):
    return await VisitService(db).create(body, current_user)


@router.get("", response_model=Paginated[VisitOut])
async def list_visits(
    db: Database,
    _: AccessDep,
    search: str | None = Query(default=None),
    from_date: str | None = Query(default=None),
    to_date: str | None = Query(default=None),
    call_center_id: str | None = Query(default=None),
    sales_employee_id: str | None = Query(default=None),
    sort_dir: str = Query(default="desc", pattern="^(asc|desc)$"),
    page: int = Query(1, ge=1),
    page_size: int = Query(30, ge=1, le=100),
):
    items, total = await VisitService(db).list_visits(
        search=search,
        from_date=from_date,
        to_date=to_date,
        call_center_id=call_center_id,
        sales_employee_id=sales_employee_id,
        sort_dir=sort_dir,
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


@router.get("/customer/{customer_id}", response_model=list[VisitOut])
async def list_customer_visits(customer_id: str, db: Database, _: AccessDep):
    return await VisitService(db).list_by_customer(customer_id)


@router.patch("/{visit_id}", response_model=VisitOut)
async def update_visit(visit_id: str, body: VisitUpdate, db: Database, _: CreateDep):
    return await VisitService(db).update(visit_id, body)
