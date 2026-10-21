from motor.motor_asyncio import AsyncIOMotorDatabase

from app.models.collections import Collections
from app.schemas.user import UserCreate, UserUpdate
from app.utils.enums import UserRole
from app.utils.helpers import oid, serialize_doc, serialize_docs, utcnow
from app.utils.security import hash_password


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

    async def list_users(self, role: str | None = None, active_only: bool = True) -> list[dict]:
        query: dict = {}
        if role:
            query["role"] = role
        if active_only:
            query["is_active"] = True
        cursor = self.col.find(query).sort("full_name", 1)
        return serialize_docs(await cursor.to_list(500))

    async def update(self, user_id: str, data: UserUpdate) -> dict | None:
        updates = {k: v for k, v in data.model_dump(exclude_unset=True).items() if v is not None}
        if "password" in updates:
            updates["password_hash"] = hash_password(updates.pop("password"))
        if "role" in updates:
            value = updates["role"]
            updates["role"] = value.value if isinstance(value, UserRole) else value
        if not updates:
            return await self.get_by_id(user_id)
        updates["updated_at"] = utcnow()
        await self.col.update_one({"_id": oid(user_id, "user")}, {"$set": updates})
        return await self.get_by_id(user_id)

    async def name_map(self, ids: list[str]) -> dict[str, str]:
        if not ids:
            return {}
        object_ids = [oid(i, "user") for i in ids if i]
        cursor = self.col.find({"_id": {"$in": object_ids}}, {"full_name": 1})
        docs = await cursor.to_list(len(object_ids))
        return {str(d["_id"]): d["full_name"] for d in docs}
