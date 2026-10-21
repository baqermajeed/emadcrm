from fastapi import HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.models.collections import Collections
from app.schemas.reservation import ReservationCreate, ReservationUpdate
from app.services.user_service import UserService
from app.utils.enums import ReservationStatus
from app.utils.helpers import oid, serialize_doc, serialize_docs, utcnow


class ReservationService:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db
        self.col = db[Collections.RESERVATIONS]
        self.customers = db[Collections.CUSTOMERS]
        self.users = UserService(db)

    async def _enrich(self, docs: list[dict]) -> list[dict]:
        ids = list({d.get("sales_employee_id") for d in docs if d.get("sales_employee_id")})
        profiles = await self.users.profile_map(ids)
        for d in docs:
            profile = profiles.get(d.get("sales_employee_id") or "", {})
            d["sales_employee_name"] = profile.get("full_name")
            d["sales_employee_avatar_url"] = profile.get("avatar_url")
        return docs

    async def create(self, data: ReservationCreate, actor: dict) -> dict:
        customer = await self.customers.find_one({"_id": oid(data.customer_id, "customer")})
        if not customer:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer not found")

        sales_id = data.sales_employee_id or str(customer.get("sales_employee_id") or "")
        if not sales_id:
            raise HTTPException(status_code=400, detail="sales_employee_id is required")

        sales = await self.users.get_by_id(sales_id)
        if not sales or sales["role"] != "sales":
            raise HTTPException(status_code=400, detail="Invalid sales employee")

        now = utcnow()
        payload = data.model_dump()
        payload["payment_type"] = data.payment_type.value
        payload["sales_employee_id"] = sales_id
        payload["reservation_date"] = data.reservation_date or now
        payload["status"] = ReservationStatus.ACTIVE.value
        payload["created_at"] = now
        payload["updated_at"] = None

        result = await self.col.insert_one(payload)
        payload["_id"] = result.inserted_id
        out = serialize_doc(payload)
        return (await self._enrich([out]))[0]

    async def list_reservations(
        self,
        *,
        customer_id: str | None = None,
        sales_employee_id: str | None = None,
        status_filter: str | None = None,
        page: int = 1,
        page_size: int = 50,
    ) -> tuple[list[dict], int]:
        query: dict = {}
        if customer_id:
            query["customer_id"] = customer_id
        if sales_employee_id:
            query["sales_employee_id"] = sales_employee_id
        if status_filter:
            query["status"] = status_filter

        total = await self.col.count_documents(query)
        skip = (page - 1) * page_size
        cursor = self.col.find(query).sort("reservation_date", -1).skip(skip).limit(page_size)
        docs = serialize_docs(await cursor.to_list(page_size))
        return await self._enrich(docs), total

    async def update(self, reservation_id: str, data: ReservationUpdate) -> dict:
        doc = await self.col.find_one({"_id": oid(reservation_id, "reservation")})
        if not doc:
            raise HTTPException(status_code=404, detail="Reservation not found")

        updates = {k: v for k, v in data.model_dump(exclude_unset=True).items() if v is not None}
        if "status" in updates:
            updates["status"] = (
                updates["status"].value
                if hasattr(updates["status"], "value")
                else updates["status"]
            )
        if updates:
            updates["updated_at"] = utcnow()
            await self.col.update_one({"_id": oid(reservation_id, "reservation")}, {"$set": updates})

        refreshed = await self.col.find_one({"_id": oid(reservation_id, "reservation")})
        out = serialize_doc(refreshed)
        return (await self._enrich([out]))[0]
