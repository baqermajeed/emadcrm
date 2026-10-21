from fastapi import HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.models.collections import Collections
from app.schemas.deal import DealCreate, DealUpdate
from app.services.user_service import UserService
from app.utils.enums import DealStatus, HouseType, PaymentType
from app.utils.helpers import oid, serialize_doc, serialize_docs, utcnow


class DealService:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db
        self.col = db[Collections.DEALS]
        self.customers = db[Collections.CUSTOMERS]
        self.users = UserService(db)

    async def _enrich(self, docs: list[dict]) -> list[dict]:
        ids = list({d.get("sales_employee_id") for d in docs if d.get("sales_employee_id")})
        profiles = await self.users.profile_map(ids)
        for d in docs:
            profile = profiles.get(d.get("sales_employee_id") or "", {})
            d["sales_employee_name"] = profile.get("full_name")
            d["sales_employee_avatar_url"] = profile.get("avatar_url")
            # Legacy deals without the new fields.
            d.setdefault("status", DealStatus.COMPLETED.value)
            d.setdefault("house_type", HouseType.HOUSE.value)
        return docs

    async def create(self, data: DealCreate, actor: dict) -> dict:
        customer = await self.customers.find_one({"_id": oid(data.customer_id, "customer")})
        if not customer:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer not found")

        sales_id = data.sales_employee_id
        if actor["role"] == "sales":
            sales_id = actor["id"]
            if str(customer.get("sales_employee_id")) != actor["id"]:
                raise HTTPException(status_code=403, detail="Not your customer")
        elif not sales_id:
            sales_id = str(customer.get("sales_employee_id") or "")

        if not sales_id:
            raise HTTPException(status_code=400, detail="sales_employee_id is required")

        sales = await self.users.get_by_id(sales_id)
        if not sales or sales["role"] != "sales":
            raise HTTPException(status_code=400, detail="Invalid sales employee")

        now = utcnow()
        payload = data.model_dump()
        payload["payment_type"] = data.payment_type.value
        payload["house_type"] = data.house_type.value
        payload["status"] = DealStatus.COMPLETED.value
        payload["email"] = str(data.email) if data.email else None
        payload["sales_employee_id"] = sales_id
        payload["sale_date"] = data.sale_date or now
        payload["created_at"] = now

        result = await self.col.insert_one(payload)
        payload["_id"] = result.inserted_id
        out = serialize_doc(payload)
        return (await self._enrich([out]))[0]

    async def list_deals(
        self,
        *,
        customer_id: str | None = None,
        sales_employee_id: str | None = None,
        page: int = 1,
        page_size: int = 50,
    ) -> tuple[list[dict], int]:
        query: dict = {}
        if customer_id:
            query["customer_id"] = customer_id
        if sales_employee_id:
            query["sales_employee_id"] = sales_employee_id

        total = await self.col.count_documents(query)
        skip = (page - 1) * page_size
        cursor = self.col.find(query).sort("sale_date", -1).skip(skip).limit(page_size)
        docs = serialize_docs(await cursor.to_list(page_size))
        return await self._enrich(docs), total

    async def get(self, deal_id: str) -> dict:
        doc = await self.col.find_one({"_id": oid(deal_id, "deal")})
        if not doc:
            raise HTTPException(status_code=404, detail="Deal not found")
        out = serialize_doc(doc)
        return (await self._enrich([out]))[0]

    async def update(self, deal_id: str, data: DealUpdate, actor: dict) -> dict:
        existing = await self.col.find_one({"_id": oid(deal_id, "deal")})
        if not existing:
            raise HTTPException(status_code=404, detail="Deal not found")

        if actor["role"] == "sales" and str(existing.get("sales_employee_id")) != actor["id"]:
            raise HTTPException(status_code=403, detail="Not your deal")

        updates = {k: v for k, v in data.model_dump(exclude_unset=True).items() if v is not None}

        if "payment_type" in updates:
            value = updates["payment_type"]
            updates["payment_type"] = value.value if isinstance(value, PaymentType) else value

        if "house_type" in updates:
            value = updates["house_type"]
            updates["house_type"] = value.value if isinstance(value, HouseType) else value

        if "email" in updates:
            updates["email"] = str(updates["email"]) if updates["email"] else None

        if "sales_employee_id" in updates:
            if actor["role"] == "sales":
                updates["sales_employee_id"] = actor["id"]
            else:
                sales = await self.users.get_by_id(updates["sales_employee_id"])
                if not sales or sales["role"] != "sales":
                    raise HTTPException(status_code=400, detail="Invalid sales employee")

        if updates:
            # Deals are always completed in this product.
            updates["status"] = DealStatus.COMPLETED.value
            updates["updated_at"] = utcnow()
            await self.col.update_one({"_id": oid(deal_id, "deal")}, {"$set": updates})

        return await self.get(deal_id)
