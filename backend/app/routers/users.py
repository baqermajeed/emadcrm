from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.dependencies import CurrentUser, Database, require_roles
from app.schemas.user import UserCreate, UserOut, UserUpdate
from app.services.user_service import UserService
from app.utils.enums import UserRole

router = APIRouter(prefix="/users", tags=["Users"])

ManagerDep = Annotated[dict, Depends(require_roles(UserRole.MANAGER))]


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
    include_inactive: bool = Query(default=False),
):
    active_only = True
    if include_inactive:
        if current_user["role"] != UserRole.MANAGER.value:
            raise HTTPException(status_code=403, detail="Managers only")
        active_only = False
    return await UserService(db).list_users(
        role=role.value if role else None,
        active_only=active_only,
    )


@router.get("/{user_id}", response_model=UserOut)
async def get_user(user_id: str, db: Database, _: ManagerDep):
    user = await UserService(db).get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.patch("/{user_id}", response_model=UserOut)
async def update_user(user_id: str, body: UserUpdate, db: Database, _: ManagerDep):
    user = await UserService(db).update(user_id, body)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
