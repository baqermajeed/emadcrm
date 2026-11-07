from fastapi import APIRouter, HTTPException, Request, Response, status

from app.dependencies import CurrentUser, Database
from app.schemas.auth import LoginRequest, TokenResponse
from app.schemas.user import UserOut
from app.config import get_settings
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Auth"])


def _set_refresh_cookie(response: Response, refresh_token: str) -> None:
    settings = get_settings()
    cookie_domain = settings.refresh_cookie_domain or None
    response.set_cookie(
        key=settings.refresh_cookie_name,
        value=refresh_token,
        httponly=True,
        secure=settings.refresh_cookie_secure,
        samesite=settings.refresh_cookie_samesite,
        max_age=settings.refresh_token_expire_days * 24 * 60 * 60,
        path="/",
        domain=cookie_domain,
    )
    # Native desktop clients read this header; the website proxy does not forward it.
    response.headers["X-Refresh-Token"] = refresh_token


def _clear_refresh_cookie(response: Response) -> None:
    settings = get_settings()
    cookie_domain = settings.refresh_cookie_domain or None
    response.delete_cookie(
        key=settings.refresh_cookie_name,
        path="/",
        domain=cookie_domain,
    )


def _read_refresh_token(request: Request) -> str | None:
    settings = get_settings()
    cookie_token = request.cookies.get(settings.refresh_cookie_name)
    if cookie_token:
        return cookie_token
    header_token = request.headers.get("X-Refresh-Token")
    if header_token and header_token.strip():
        return header_token.strip()
    return None


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, response: Response, db: Database):
    payload, refresh_token = await AuthService(db).login(body.username, body.password)
    _set_refresh_cookie(response, refresh_token)
    return payload


@router.post("/refresh", response_model=TokenResponse)
async def refresh(request: Request, response: Response, db: Database):
    refresh_token = _read_refresh_token(request)
    if not refresh_token:
        _clear_refresh_cookie(response)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token missing")

    payload, next_refresh_token = await AuthService(db).refresh(refresh_token)
    _set_refresh_cookie(response, next_refresh_token)
    return payload


@router.post("/logout")
async def logout(request: Request, response: Response, db: Database):
    refresh_token = _read_refresh_token(request)
    await AuthService(db).logout(refresh_token)
    _clear_refresh_cookie(response)
    return {"ok": True}


@router.get("/me", response_model=UserOut)
async def me(current_user: CurrentUser):
    return UserOut(**current_user)
