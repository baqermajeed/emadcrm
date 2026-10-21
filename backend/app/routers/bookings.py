from math import ceil
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status

from app.dependencies import CurrentUser, Database, require_roles
from app.schemas.booking import BookingApprove, BookingCreate, BookingOut, BookingUpdate
from app.schemas.common import Paginated
from app.services.booking_service import BookingService
from app.utils.enums import BookingStatus, UserRole

router = APIRouter(prefix="/bookings", tags=["Bookings"])

CallCenterDep = Annotated[dict, Depends(require_roles(UserRole.CALL_CENTER))]
ReceptionDep = Annotated[
    dict, Depends(require_roles(UserRole.RECEPTION, UserRole.MANAGER))
]
StaffDep = Annotated[
    dict,
    Depends(
        require_roles(
            UserRole.CALL_CENTER,
            UserRole.RECEPTION,
            UserRole.MANAGER,
        )
    ),
]


@router.post("", response_model=BookingOut, status_code=status.HTTP_201_CREATED)
async def create_booking(body: BookingCreate, db: Database, current_user: CallCenterDep):
    # Manager creating on behalf not typical; call center uses own id
    actor = current_user
    if current_user["role"] == UserRole.MANAGER.value:
        actor = current_user
    return await BookingService(db).create(body, actor)


@router.get("", response_model=Paginated[BookingOut])
async def list_bookings(
    db: Database,
    current_user: StaffDep,
    status_filter: BookingStatus | None = Query(default=None, alias="status"),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
):
    call_center_id = None
    if current_user["role"] == UserRole.CALL_CENTER.value:
        call_center_id = current_user["id"]

    items, total = await BookingService(db).list_bookings(
        status_filter=status_filter.value if status_filter else None,
        call_center_id=call_center_id,
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


@router.get("/{booking_id}", response_model=BookingOut)
async def get_booking(booking_id: str, db: Database, _: StaffDep):
    return await BookingService(db).get(booking_id)


@router.patch("/{booking_id}", response_model=BookingOut)
async def update_booking(
    booking_id: str,
    body: BookingUpdate,
    db: Database,
    current_user: Annotated[
        dict,
        Depends(require_roles(UserRole.CALL_CENTER, UserRole.RECEPTION, UserRole.MANAGER)),
    ],
):
    return await BookingService(db).update(booking_id, body, current_user)


@router.post("/{booking_id}/approve", response_model=BookingOut)
async def approve_booking(
    booking_id: str,
    body: BookingApprove,
    db: Database,
    current_user: ReceptionDep,
):
    return await BookingService(db).approve(booking_id, body, current_user)
