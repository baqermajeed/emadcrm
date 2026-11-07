import uuid

from fastapi import HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.models.collections import Collections
from app.schemas.auth import TokenResponse
from app.schemas.user import UserOut
from app.services.user_service import UserService
from app.utils.helpers import oid, serialize_doc, utcnow
from app.utils.security import (
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    verify_password,
)


class AuthService:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db
        self.users = UserService(db)
        self.col = db[Collections.USERS]

    async def login(self, username: str, password: str) -> tuple[TokenResponse, str]:
        user = await self.users.get_by_username(username)
        if not user or not verify_password(password, user["password_hash"]):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid username or password",
            )
        if not user.get("is_active", True):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is disabled",
            )
        return await self._issue_session(user)

    async def refresh(self, refresh_token: str) -> tuple[TokenResponse, str]:
        try:
            payload = decode_refresh_token(refresh_token)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired refresh token",
            ) from exc

        user_id = payload.get("sub")
        token_jti = payload.get("jti")
        if not user_id or not token_jti:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token payload",
            )

        user = await self.col.find_one({"_id": oid(user_id, "user")})
        if not user or not user.get("is_active", True):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User inactive",
            )

        if user.get("refresh_token_jti") != token_jti:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Refresh token revoked",
            )

        return await self._issue_session(user)

    async def logout(self, refresh_token: str | None) -> None:
        if not refresh_token:
            return
        try:
            payload = decode_refresh_token(refresh_token)
        except ValueError:
            return
        user_id = payload.get("sub")
        token_jti = payload.get("jti")
        if not user_id or not token_jti:
            return
        await self.col.update_one(
            {"_id": oid(user_id, "user"), "refresh_token_jti": token_jti},
            {
                "$unset": {
                    "refresh_token_jti": "",
                    "refresh_token_expires_at": "",
                },
                "$set": {"updated_at": utcnow()},
            },
        )

    async def _issue_session(self, user: dict) -> tuple[TokenResponse, str]:
        serialized = serialize_doc(user)
        refresh_jti = uuid.uuid4().hex
        refresh_token, refresh_expire_at = create_refresh_token(
            subject=serialized["id"],
            jti=refresh_jti,
        )
        await self.col.update_one(
            {"_id": oid(serialized["id"], "user")},
            {
                "$set": {
                    "refresh_token_jti": refresh_jti,
                    "refresh_token_expires_at": refresh_expire_at,
                    "updated_at": utcnow(),
                }
            },
        )
        token = create_access_token(
            subject=serialized["id"],
            extra={"role": serialized["role"], "username": serialized["username"]},
        )
        return TokenResponse(
            access_token=token,
            user=UserOut(**{k: v for k, v in serialized.items() if k != "password_hash"}),
        ), refresh_token
