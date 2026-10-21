from math import ceil
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status

from app.dependencies import Database, require_roles
from app.schemas.common import Paginated
from app.schemas.reservation import ReservationCreate, ReservationOut, ReservationUpdate
from app.services.reservation_service import ReservationService
from app.utils.enums import ReservationStatus, UserRole

router = APIRouter(prefix="/reservations", tags=["Reservations"])

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
EditDep = Annotated[
    dict,
    Depends(require_roles(UserRole.RECEPTION, UserRole.MANAGER)),
]


@router.post("", response_model=ReservationOut, status_code=status.HTTP_201_CREATED)
async def create_reservation(body: ReservationCreate, db: Database, current_user: EditDep):
    return await ReservationService(db).create(body, current_user)


@router.get("", response_model=Paginated[ReservationOut])
async def list_reservations(
    db: Database,
    current_user: AccessDep,
    customer_id: str | None = None,
    status_filter: ReservationStatus | None = Query(default=None, alias="status"),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
):
    sales_id = current_user["id"] if current_user["role"] == UserRole.SALES.value else None
    items, total = await ReservationService(db).list_reservations(
        customer_id=customer_id,
        sales_employee_id=sales_id,
        status_filter=status_filter.value if status_filter else None,
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


@router.patch("/{reservation_id}", response_model=ReservationOut)
async def update_reservation(
    reservation_id: str,
    body: ReservationUpdate,
    db: Database,
    _: EditDep,
):
    return await ReservationService(db).update(reservation_id, body)
