from math import ceil
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, Query, UploadFile, status

from app.dependencies import CurrentUser, Database, require_roles
from app.schemas.common import Paginated
from app.schemas.customer import CustomerCreate, CustomerOut, CustomerUpdate, DocumentOut
from app.services.customer_service import CustomerService
from app.utils.enums import UserRole

router = APIRouter(prefix="/customers", tags=["Customers"])

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


@router.get("", response_model=Paginated[CustomerOut])
async def list_customers(
    db: Database,
    current_user: AccessDep,
    search: str | None = Query(default=None),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
):
    sales_id = None
    if current_user["role"] == UserRole.SALES.value:
        sales_id = current_user["id"]

    items, total = await CustomerService(db).list_customers(
        sales_employee_id=sales_id,
        search=search,
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


@router.post("", response_model=CustomerOut, status_code=status.HTTP_201_CREATED)
async def create_customer(
    body: CustomerCreate,
    db: Database,
    _: EditDep,
):
    return await CustomerService(db).create(body)


@router.get("/{customer_id}", response_model=CustomerOut)
async def get_customer(customer_id: str, db: Database, current_user: AccessDep):
    customer = await CustomerService(db).get(customer_id)
    if (
        current_user["role"] == UserRole.SALES.value
        and customer.get("sales_employee_id") != current_user["id"]
    ):
        from fastapi import HTTPException

        raise HTTPException(status_code=403, detail="Not your customer")
    return customer


@router.patch("/{customer_id}", response_model=CustomerOut)
async def update_customer(
    customer_id: str,
    body: CustomerUpdate,
    db: Database,
    _: EditDep,
):
    return await CustomerService(db).update(customer_id, body)


@router.post(
    "/{customer_id}/documents",
    response_model=DocumentOut,
    status_code=status.HTTP_201_CREATED,
)
async def upload_document(
    customer_id: str,
    db: Database,
    current_user: EditDep,
    file: UploadFile = File(...),
    notes: str | None = Form(default=None),
):
    return await CustomerService(db).upload_document(
        customer_id, file, current_user["id"], notes=notes
    )


@router.delete("/{customer_id}/documents/{document_id}", response_model=CustomerOut)
async def delete_document(
    customer_id: str,
    document_id: str,
    db: Database,
    _: EditDep,
):
    return await CustomerService(db).delete_document(customer_id, document_id)
