from math import ceil
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status

from app.dependencies import CurrentUser, Database, require_roles
from app.schemas.common import Paginated
from app.schemas.customer import CustomerCreate, CustomerOut, CustomerUpdate, DocumentOut
from app.schemas.customer_note import CustomerSalesNoteCreate, CustomerSalesNoteOut
from app.services.customer_service import CustomerService
from app.utils.enums import UserRole

router = APIRouter(prefix="/customers", tags=["Customers"])

AccessDep = Annotated[
    dict,
    Depends(
        require_roles(
            UserRole.CALL_CENTER,
            UserRole.RECEPTION,
            UserRole.SALES,
            UserRole.MANAGER,
        )
    ),
]
EditDep = Annotated[
    dict,
    Depends(require_roles(UserRole.RECEPTION, UserRole.MANAGER, UserRole.SALES)),
]
SalesOnlyDep = Annotated[
    dict,
    Depends(require_roles(UserRole.SALES)),
]


@router.get("", response_model=Paginated[CustomerOut])
async def list_customers(
    db: Database,
    current_user: AccessDep,
    search: str | None = Query(default=None),
    status: str | None = Query(default=None),
    from_date: str | None = Query(default=None),
    to_date: str | None = Query(default=None),
    sort_dir: str = Query(default="desc", pattern="^(asc|desc)$"),
    page: int = Query(1, ge=1),
    page_size: int = Query(30, ge=1, le=100),
    limit: int | None = Query(default=None, ge=1, le=100),
):
    effective_page_size = limit or page_size
    sales_id = None
    if current_user["role"] == UserRole.SALES.value:
        sales_id = current_user["id"]

    items, total = await CustomerService(db).list_customers(
        sales_employee_id=sales_id,
        search=search,
        status=status,
        from_date=from_date,
        to_date=to_date,
        sort_dir=sort_dir,
        page=page,
        page_size=effective_page_size,
    )
    return Paginated(
        items=items,
        total=total,
        page=page,
        page_size=effective_page_size,
        pages=ceil(total / effective_page_size) if effective_page_size else 0,
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
    current_user: EditDep,
):
    if current_user["role"] == UserRole.SALES.value:
        customer = await CustomerService(db).get(customer_id)
        if customer.get("sales_employee_id") != current_user["id"]:
            raise HTTPException(status_code=403, detail="Not your customer")
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
    if current_user["role"] == UserRole.SALES.value:
        customer = await CustomerService(db).get(customer_id)
        if customer.get("sales_employee_id") != current_user["id"]:
            raise HTTPException(status_code=403, detail="Not your customer")
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


@router.get("/{customer_id}/sales-notes", response_model=list[CustomerSalesNoteOut])
async def list_sales_notes(customer_id: str, db: Database, current_user: SalesOnlyDep):
    return await CustomerService(db).list_sales_notes(customer_id, current_user["id"])


@router.post(
    "/{customer_id}/sales-notes",
    response_model=CustomerSalesNoteOut,
    status_code=status.HTTP_201_CREATED,
)
async def add_sales_note(
    customer_id: str,
    body: CustomerSalesNoteCreate,
    db: Database,
    current_user: SalesOnlyDep,
):
    return await CustomerService(db).add_sales_note(customer_id, current_user["id"], body.note)
