from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.dependencies import Database, require_roles
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


@router.get("/customer/{customer_id}", response_model=list[VisitOut])
async def list_customer_visits(customer_id: str, db: Database, _: AccessDep):
    return await VisitService(db).list_by_customer(customer_id)


@router.patch("/{visit_id}", response_model=VisitOut)
async def update_visit(visit_id: str, body: VisitUpdate, db: Database, _: CreateDep):
    return await VisitService(db).update(visit_id, body)
