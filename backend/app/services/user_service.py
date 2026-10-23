import uuid
from pathlib import Path

import aiofiles
from fastapi import HTTPException, UploadFile
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.config import get_settings
from app.models.collections import Collections
from app.schemas.user import UserCreate, UserUpdate
from app.utils.enums import UserRole
from app.utils.helpers import oid, serialize_doc, serialize_docs, utcnow
from app.utils.security import hash_password

_ALLOWED_IMAGE_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/gif",
}
_EXT_CONTENT_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".gif": "image/gif",
}


class UserService:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.col = db[Collections.USERS]

    async def create(self, data: UserCreate) -> dict:
        existing = await self.col.find_one({"username": data.username})
        if existing:
            raise ValueError("Username already exists")

        now = utcnow()
        doc = {
            "username": data.username,
            "password_hash": hash_password(data.password),
            "full_name": data.full_name,
            "role": data.role.value,
            "phone": data.phone,
            "avatar_url": None,
            "is_active": data.is_active,
            "created_at": now,
            "updated_at": None,
        }
        result = await self.col.insert_one(doc)
        doc["_id"] = result.inserted_id
        return serialize_doc(doc)

    async def get_by_id(self, user_id: str) -> dict | None:
        doc = await self.col.find_one({"_id": oid(user_id, "user")})
        return serialize_doc(doc)

    async def get_by_username(self, username: str) -> dict | None:
        return await self.col.find_one({"username": username})

    async def list_users(
        self,
        role: str | None = None,
        search: str | None = None,
        active_only: bool = True,
    ) -> list[dict]:
        query: dict = {}
        if role:
            query["role"] = role
        if search:
            query["$or"] = [
                {"full_name": {"$regex": search, "$options": "i"}},
                {"username": {"$regex": search, "$options": "i"}},
                {"phone": {"$regex": search, "$options": "i"}},
            ]
        if active_only:
            query["is_active"] = True
        cursor = self.col.find(query).sort("full_name", 1)
        return serialize_docs(await cursor.to_list(500))

    async def update(self, user_id: str, data: UserUpdate) -> dict | None:
        raw = data.model_dump(exclude_unset=True)
        clear_avatar = bool(raw.pop("clear_avatar", False))
        updates = {k: v for k, v in raw.items() if v is not None}

        if "username" in updates:
            username = updates["username"]
            clash = await self.col.find_one(
                {
                    "username": username,
                    "_id": {"$ne": oid(user_id, "user")},
                }
            )
            if clash:
                raise ValueError("Username already exists")

        if "password" in updates:
            updates["password_hash"] = hash_password(updates.pop("password"))
        if "role" in updates:
            value = updates["role"]
            updates["role"] = value.value if isinstance(value, UserRole) else value

        if clear_avatar:
            current = await self.get_by_id(user_id)
            if current and current.get("avatar_url"):
                self._delete_avatar_file(current["avatar_url"])
            updates["avatar_url"] = None

        if not updates:
            return await self.get_by_id(user_id)

        updates["updated_at"] = utcnow()
        await self.col.update_one({"_id": oid(user_id, "user")}, {"$set": updates})
        return await self.get_by_id(user_id)

    async def upload_avatar(self, user_id: str, file: UploadFile) -> dict:
        user = await self.get_by_id(user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        settings = get_settings()
        upload_root = Path(settings.upload_dir) / "users" / user_id
        upload_root.mkdir(parents=True, exist_ok=True)

        ext = Path(file.filename or "avatar.jpg").suffix.lower() or ".jpg"
        raw_type = (file.content_type or "").split(";")[0].strip().lower()
        content_type = raw_type or _EXT_CONTENT_TYPES.get(ext, "")
        if content_type == "image/jpg":
            content_type = "image/jpeg"
        if content_type == "application/octet-stream":
            content_type = _EXT_CONTENT_TYPES.get(ext, content_type)

        allowed = content_type in _ALLOWED_IMAGE_TYPES or ext in _EXT_CONTENT_TYPES
        if not allowed:
            raise HTTPException(status_code=400, detail="يجب أن تكون الصورة JPG أو PNG أو WebP")
        if not content_type or content_type == "application/octet-stream":
            content_type = _EXT_CONTENT_TYPES.get(ext, "image/jpeg")

        stored_name = f"avatar_{uuid.uuid4().hex}{ext}"
        dest = upload_root / stored_name

        size = 0
        max_bytes = settings.max_upload_size_mb * 1024 * 1024
        async with aiofiles.open(dest, "wb") as out:
            while chunk := await file.read(1024 * 1024):
                size += len(chunk)
                if size > max_bytes:
                    await out.close()
                    dest.unlink(missing_ok=True)
                    raise HTTPException(status_code=400, detail="File too large")
                await out.write(chunk)

        if user.get("avatar_url"):
            self._delete_avatar_file(user["avatar_url"])

        avatar_url = f"/uploads/users/{user_id}/{stored_name}"
        await self.col.update_one(
            {"_id": oid(user_id, "user")},
            {"$set": {"avatar_url": avatar_url, "updated_at": utcnow()}},
        )
        refreshed = await self.get_by_id(user_id)
        if not refreshed:
            raise HTTPException(status_code=404, detail="User not found")
        return refreshed

    def _delete_avatar_file(self, avatar_url: str) -> None:
        settings = get_settings()
        # avatar_url like /uploads/users/{id}/{file}
        relative = avatar_url.lstrip("/").removeprefix("uploads/").lstrip("/")
        path = Path(settings.upload_dir) / relative
        path.unlink(missing_ok=True)

    async def profile_map(self, ids: list[str]) -> dict[str, dict]:
        """Map user id -> {full_name, avatar_url}."""
        if not ids:
            return {}
        object_ids = [oid(i, "user") for i in ids if i]
        cursor = self.col.find(
            {"_id": {"$in": object_ids}},
            {"full_name": 1, "avatar_url": 1},
        )
        docs = await cursor.to_list(len(object_ids))
        return {
            str(d["_id"]): {
                "full_name": d.get("full_name"),
                "avatar_url": d.get("avatar_url"),
            }
            for d in docs
        }

    async def name_map(self, ids: list[str]) -> dict[str, str]:
        profiles = await self.profile_map(ids)
        return {
            k: v["full_name"]
            for k, v in profiles.items()
            if v.get("full_name")
        }
