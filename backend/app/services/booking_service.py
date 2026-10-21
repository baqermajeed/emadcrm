from fastapi import HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.models.collections import Collections
from app.schemas.booking import BookingApprove, BookingCreate, BookingUpdate
from app.services.user_service import UserService
from app.utils.enums import BookingStatus
from app.utils.helpers import oid, serialize_doc, serialize_docs, utcnow


class BookingService:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db
        self.col = db[Collections.BOOKINGS]
        self.customers = db[Collections.CUSTOMERS]
        self.visits = db[Collections.VISITS]
        self.users = UserService(db)

    async def _enrich(self, docs: list[dict]) -> list[dict]:
        ids = list({d.get("call_center_id") for d in docs if d.get("call_center_id")})
        names = await self.users.name_map(ids)
        for d in docs:
            d["call_center_name"] = names.get(d.get("call_center_id") or "")
        return docs

    async def create(self, data: BookingCreate, call_center: dict) -> dict:
        now = utcnow()
        doc = {
            **data.model_dump(),
            "source": data.source.value,
            "status": BookingStatus.PENDING.value,
            "call_center_id": call_center["id"],
            "customer_id": None,
            "approved_by": None,
            "approved_at": None,
            "created_at": now,
            "updated_at": None,
        }
        result = await self.col.insert_one(doc)
        doc["_id"] = result.inserted_id
        out = serialize_doc(doc)
        out["call_center_name"] = call_center.get("full_name")
        return out

    async def list_bookings(
        self,
        *,
        status_filter: str | None = None,
        call_center_id: str | None = None,
        page: int = 1,
        page_size: int = 50,
    ) -> tuple[list[dict], int]:
        query: dict = {}
        if status_filter:
            query["status"] = status_filter
        if call_center_id:
            query["call_center_id"] = call_center_id

        total = await self.col.count_documents(query)
        skip = (page - 1) * page_size
        cursor = self.col.find(query).sort("visit_date", -1).skip(skip).limit(page_size)
        docs = serialize_docs(await cursor.to_list(page_size))
        return await self._enrich(docs), total

    async def get(self, booking_id: str) -> dict:
        doc = await self.col.find_one({"_id": oid(booking_id, "booking")})
        if not doc:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
        out = serialize_doc(doc)
        enriched = await self._enrich([out])
        return enriched[0]

    async def update(self, booking_id: str, data: BookingUpdate, actor: dict) -> dict:
        booking = await self.get(booking_id)
        if actor["role"] == "call_center" and booking["call_center_id"] != actor["id"]:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your booking")
        if booking["status"] != BookingStatus.PENDING.value and actor["role"] == "call_center":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot edit approved booking")

        updates = {k: v for k, v in data.model_dump(exclude_unset=True).items() if v is not None}
        if "source" in updates:
            updates["source"] = updates["source"].value if hasattr(updates["source"], "value") else updates["source"]
        if "status" in updates:
            updates["status"] = updates["status"].value if hasattr(updates["status"], "value") else updates["status"]
        if updates:
            updates["updated_at"] = utcnow()
            await self.col.update_one({"_id": oid(booking_id, "booking")}, {"$set": updates})
        return await self.get(booking_id)

    async def approve(self, booking_id: str, data: BookingApprove, reception: dict) -> dict:
        booking = await self.get(booking_id)
        if booking["status"] != BookingStatus.PENDING.value:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Booking already processed")

        sales = await self.users.get_by_id(data.sales_employee_id)
        if not sales or sales["role"] != "sales":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid sales employee")

        now = utcnow()
        customer_doc = {
            "name": booking["name"],
            "profession": data.profession,
            "address": data.address,
            "phone": booking["phone"],
            "call_center_id": booking["call_center_id"],
            "how_knew": data.how_knew.value if data.how_knew else None,
            "referral_buyer_name": data.referral_buyer_name,
            "sales_employee_id": data.sales_employee_id,
            "notes": data.notes or booking.get("notes"),
            "booking_id": booking["id"],
            "documents": [],
            "created_at": now,
            "updated_at": None,
        }
        customer_result = await self.customers.insert_one(customer_doc)
        customer_id = str(customer_result.inserted_id)

        await self.visits.insert_one(
            {
                "customer_id": customer_id,
                "visit_date": now,
                "notes": "First visit — booking approved",
                "sales_employee_id": data.sales_employee_id,
                "recorded_by": reception["id"],
                "created_at": now,
            }
        )

        await self.col.update_one(
            {"_id": oid(booking_id, "booking")},
            {
                "$set": {
                    "status": BookingStatus.APPROVED.value,
                    "customer_id": customer_id,
                    "approved_by": reception["id"],
                    "approved_at": now,
                    "updated_at": now,
                }
            },
        )
        return await self.get(booking_id)
