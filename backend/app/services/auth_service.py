from fastapi import HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.schemas.auth import TokenResponse
from app.schemas.user import UserOut
from app.services.user_service import UserService
from app.utils.helpers import serialize_doc
from app.utils.security import create_access_token, verify_password


class AuthService:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.users = UserService(db)

    async def login(self, username: str, password: str) -> TokenResponse:
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

        serialized = serialize_doc(user)
        token = create_access_token(
            subject=serialized["id"],
            extra={"role": serialized["role"], "username": serialized["username"]},
        )
        return TokenResponse(
            access_token=token,
            user=UserOut(**{k: v for k, v in serialized.items() if k != "password_hash"}),
        )
