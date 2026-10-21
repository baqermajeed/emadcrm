from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.database import get_db
from app.models.collections import Collections
from app.utils.enums import UserRole
from app.utils.helpers import oid, serialize_doc
from app.utils.security import decode_access_token

bearer_scheme = HTTPBearer(auto_error=True)


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
) -> dict:
    try:
        payload = decode_access_token(credentials.credentials)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        ) from exc

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    user = await db[Collections.USERS].find_one({"_id": oid(user_id, "user")})
    if not user or not user.get("is_active", True):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User inactive")

    return serialize_doc(user)


def require_roles(*roles: UserRole):
    async def checker(current_user: Annotated[dict, Depends(get_current_user)]) -> dict:
        if current_user["role"] not in {r.value for r in roles}:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission for this action",
            )
        return current_user

    return checker


CurrentUser = Annotated[dict, Depends(get_current_user)]
Database = Annotated[AsyncIOMotorDatabase, Depends(get_db)]
