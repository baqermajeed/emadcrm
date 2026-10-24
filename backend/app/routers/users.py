from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status

from app.dependencies import CurrentUser, Database, require_roles
from app.schemas.user import UserCreate, UserOut, UserUpdate
from app.services.user_service import UserService
from app.utils.enums import UserRole

router = APIRouter(prefix="/users", tags=["Users"])

ManagerDep = Annotated[dict, Depends(require_roles(UserRole.MANAGER))]
_SELF_EDITABLE_FIELDS = {"username", "full_name", "phone", "password", "clear_avatar"}


@router.post("", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def create_user(body: UserCreate, db: Database, _: ManagerDep):
    try:
        return await UserService(db).create(body)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("", response_model=list[UserOut])
async def list_users(
    db: Database,
    current_user: CurrentUser,
    role: UserRole | None = Query(default=None),
    search: str | None = Query(default=None),
    include_inactive: bool = Query(default=False),
):
    active_only = True
    if include_inactive:
        if current_user["role"] != UserRole.MANAGER.value:
            raise HTTPException(status_code=403, detail="Managers only")
        active_only = False
    return await UserService(db).list_users(
        role=role.value if role else None,
        search=search,
        active_only=active_only,
    )


@router.get("/me", response_model=UserOut)
async def get_current_user_profile(current_user: CurrentUser):
    return UserOut(**current_user)


@router.get("/{user_id}", response_model=UserOut)
async def get_user(user_id: str, db: Database, _: ManagerDep):
    user = await UserService(db).get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.patch("/{user_id}", response_model=UserOut)
async def update_user(user_id: str, body: UserUpdate, db: Database, current_user: CurrentUser):
    is_manager = current_user["role"] == UserRole.MANAGER.value
    is_sales_self = (
        current_user["role"] == UserRole.SALES.value and current_user["id"] == user_id
    )
    if not is_manager and not is_sales_self:
        raise HTTPException(status_code=403, detail="You do not have permission for this action")

    safe_body = body
    if is_sales_self and not is_manager:
        body_data = body.model_dump(exclude_unset=True)
        forbidden = set(body_data) - _SELF_EDITABLE_FIELDS
        if forbidden:
            raise HTTPException(
                status_code=403,
                detail="Sales employee can only update personal profile fields",
            )
        safe_body = UserUpdate.model_validate(body_data)

    try:
        user = await UserService(db).update(user_id, safe_body)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.post("/{user_id}/avatar", response_model=UserOut)
async def upload_user_avatar(
    user_id: str,
    db: Database,
    current_user: CurrentUser,
    file: UploadFile = File(...),
):
    is_manager = current_user["role"] == UserRole.MANAGER.value
    is_sales_self = (
        current_user["role"] == UserRole.SALES.value and current_user["id"] == user_id
    )
    if not is_manager and not is_sales_self:
        raise HTTPException(status_code=403, detail="You do not have permission for this action")

    return await UserService(db).upload_avatar(user_id, file)
