from fastapi import HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.models.collections import Collections
from app.schemas.visit import VisitCreate, VisitUpdate
from app.services.user_service import UserService
from app.utils.helpers import oid, serialize_doc, serialize_docs, utcnow


class VisitService:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db
        self.col = db[Collections.VISITS]
        self.customers = db[Collections.CUSTOMERS]
        self.users = UserService(db)

    async def _enrich(self, docs: list[dict]) -> list[dict]:
        ids: set[str] = set()
        for d in docs:
            if d.get("sales_employee_id"):
                ids.add(d["sales_employee_id"])
            if d.get("recorded_by"):
                ids.add(d["recorded_by"])
        profiles = await self.users.profile_map(list(ids))
        for d in docs:
            sales = profiles.get(d.get("sales_employee_id") or "", {})
            recorded = profiles.get(d.get("recorded_by") or "", {})
            d["sales_employee_name"] = sales.get("full_name")
            d["sales_employee_avatar_url"] = sales.get("avatar_url")
            d["recorded_by_name"] = recorded.get("full_name")
            d["recorded_by_avatar_url"] = recorded.get("avatar_url")
        return docs

    async def create(self, data: VisitCreate, actor: dict) -> dict:
        customer = await self.customers.find_one({"_id": oid(data.customer_id, "customer")})
        if not customer:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer not found")

        sales_id = data.sales_employee_id or str(customer.get("sales_employee_id") or "")
        now = utcnow()
        doc = {
            "customer_id": data.customer_id,
            "visit_date": data.visit_date or now,
            "notes": data.notes,
            "sales_employee_id": sales_id or None,
            "recorded_by": actor["id"],
            "created_at": now,
        }
        result = await self.col.insert_one(doc)
        doc["_id"] = result.inserted_id
        out = serialize_doc(doc)
        return (await self._enrich([out]))[0]

    async def list_by_customer(self, customer_id: str) -> list[dict]:
        cursor = self.col.find({"customer_id": customer_id}).sort("visit_date", -1)
        docs = serialize_docs(await cursor.to_list(500))
        return await self._enrich(docs)

    async def update(self, visit_id: str, data: VisitUpdate) -> dict:
        existing = await self.col.find_one({"_id": oid(visit_id, "visit")})
        if not existing:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Visit not found")

        await self.col.update_one(
            {"_id": existing["_id"]},
            {"$set": {"notes": data.notes}},
        )
        doc = await self.col.find_one({"_id": existing["_id"]})
        out = serialize_doc(doc)
        return (await self._enrich([out]))[0]
