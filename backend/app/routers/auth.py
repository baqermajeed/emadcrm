from fastapi import APIRouter

from app.dependencies import CurrentUser, Database
from app.schemas.auth import LoginRequest, TokenResponse
from app.schemas.user import UserOut
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, db: Database):
    return await AuthService(db).login(body.username, body.password)


@router.get("/me", response_model=UserOut)
async def me(current_user: CurrentUser):
    return UserOut(**current_user)
