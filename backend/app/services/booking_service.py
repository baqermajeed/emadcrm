from datetime import UTC, datetime, timedelta, timezone

from fastapi import HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.models.collections import Collections
from app.schemas.booking import BookingApprove, BookingCreate, BookingUpdate
from app.services.user_service import UserService
from app.utils.enums import BookingStatus, VisitType
from app.utils.helpers import oid, serialize_doc, serialize_docs, utcnow


class BookingService:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db
        self.col = db[Collections.BOOKINGS]
        self.customers = db[Collections.CUSTOMERS]
        self.visits = db[Collections.VISITS]
        self.users = UserService(db)

    async def expire_no_shows(self) -> int:
        """Mark pending bookings as no-show 24 hours after the appointment."""
        now = utcnow()
        cutoff = now - timedelta(hours=24)
        # Legacy rows may store visit_date as naive local Baghdad time.
        # Compare those against a Baghdad-local naive cutoff to avoid timezone drift.
        baghdad_tz = timezone(timedelta(hours=3))
        cutoff_naive = (datetime.now(baghdad_tz) - timedelta(hours=24)).replace(tzinfo=None)
        result = await self.col.update_many(
            {
                "status": BookingStatus.PENDING.value,
                "$or": [
                    {"visit_date": {"$lte": cutoff}},
                    {"visit_date": {"$lte": cutoff_naive}},
                ],
            },
            {
                "$set": {
                    "status": BookingStatus.NO_SHOW.value,
                    "updated_at": now,
                }
            },
        )
        return int(result.modified_count)

    async def _enrich(self, docs: list[dict]) -> list[dict]:
        ids = list({d.get("call_center_id") for d in docs if d.get("call_center_id")})
        profiles = await self.users.profile_map(ids)
        # للبيانات القديمة بلا visit_type: إن أُنشئ الملف من نفس الحجز → أول زيارة
        legacy_customer_ids = [
            d.get("customer_id")
            for d in docs
            if d.get("status") == BookingStatus.APPROVED.value
            and not d.get("visit_type")
            and d.get("customer_id")
        ]
        booking_ids_by_customer: dict[str, str] = {}
        if legacy_customer_ids:
            cursor = self.customers.find(
                {"_id": {"$in": [oid(i, "customer") for i in legacy_customer_ids]}},
                {"booking_id": 1},
            )
            for c in await cursor.to_list(len(legacy_customer_ids)):
                if c.get("booking_id"):
                    booking_ids_by_customer[str(c["_id"])] = str(c["booking_id"])

        for d in docs:
            profile = profiles.get(d.get("call_center_id") or "", {})
            d["call_center_name"] = profile.get("full_name")
            d["call_center_avatar_url"] = profile.get("avatar_url")
            if (
                d.get("status") == BookingStatus.APPROVED.value
                and not d.get("visit_type")
                and d.get("customer_id")
            ):
                created_from = booking_ids_by_customer.get(d["customer_id"])
                d["visit_type"] = (
                    VisitType.FIRST.value
                    if created_from == d.get("id")
                    else VisitType.FOLLOW_UP.value
                )
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
        out["call_center_avatar_url"] = call_center.get("avatar_url")
        return out

    async def list_bookings(
        self,
        *,
        status_filter: str | None = None,
        call_center_id: str | None = None,
        search: str | None = None,
        from_date: str | None = None,
        to_date: str | None = None,
        sales_employee_id: str | None = None,
        sort_dir: str = "desc",
        page: int = 1,
        page_size: int = 50,
    ) -> tuple[list[dict], int]:
        query: dict = {}
        if status_filter:
            if status_filter == BookingStatus.NO_SHOW.value:
                query["status"] = {
                    "$in": [BookingStatus.NO_SHOW.value, BookingStatus.CANCELLED.value]
                }
            else:
                query["status"] = status_filter
        if call_center_id:
            query["call_center_id"] = call_center_id
        if search:
            query["$or"] = [
                {"name": {"$regex": search, "$options": "i"}},
                {"phone": {"$regex": search, "$options": "i"}},
                {"governorate": {"$regex": search, "$options": "i"}},
            ]
        if sales_employee_id:
            cursor = self.customers.find(
                {"sales_employee_id": sales_employee_id},
                {"_id": 1},
            )
            customer_ids = [str(c["_id"]) for c in await cursor.to_list(10000)]
            if not customer_ids:
                return [], 0
            query["customer_id"] = {"$in": customer_ids}

        date_clause = self._build_dual_date_clause(
            field="visit_date",
            from_raw=from_date,
            to_raw=to_date,
        )
        if date_clause:
            if "$or" in query:
                search_or = query.pop("$or")
                base = query.copy()
                and_parts = []
                if base:
                    and_parts.append(base)
                and_parts.append({"$or": search_or})
                and_parts.append(date_clause)
                query = {"$and": and_parts}
            else:
                query.update(date_clause)

        await self.expire_no_shows()
        total = await self.col.count_documents(query)
        skip = (page - 1) * page_size
        sort_value = -1 if sort_dir != "asc" else 1
        cursor = self.col.find(query).sort("created_at", sort_value).skip(skip).limit(page_size)
        docs = serialize_docs(await cursor.to_list(page_size))
        return await self._enrich(docs), total

    @staticmethod
    def _parse_iso_datetime(raw: str) -> datetime | None:
        try:
            return datetime.fromisoformat(raw.replace("Z", "+00:00"))
        except ValueError:
            return None

    @classmethod
    def _build_dual_date_clause(
        cls,
        *,
        field: str,
        from_raw: str | None,
        to_raw: str | None,
    ) -> dict | None:
        parsed_from = cls._parse_iso_datetime(from_raw) if from_raw else None
        parsed_to = cls._parse_iso_datetime(to_raw) if to_raw else None
        if parsed_from is None and parsed_to is None:
            return None

        aware_range: dict = {}
        naive_range: dict = {}

        if parsed_from is not None:
            if parsed_from.tzinfo is None:
                aware_from = parsed_from.replace(tzinfo=UTC)
                naive_from = parsed_from
            else:
                aware_from = parsed_from.astimezone(UTC)
                naive_from = parsed_from.astimezone(UTC).replace(tzinfo=None)
            aware_range["$gte"] = aware_from
            naive_range["$gte"] = naive_from

        if parsed_to is not None:
            if parsed_to.tzinfo is None:
                aware_to = parsed_to.replace(tzinfo=UTC)
                naive_to = parsed_to
            else:
                aware_to = parsed_to.astimezone(UTC)
                naive_to = parsed_to.astimezone(UTC).replace(tzinfo=None)
            aware_range["$lte"] = aware_to
            naive_range["$lte"] = naive_to

        return {
            "$or": [
                {field: aware_range},
                {field: naive_range},
            ]
        }

    async def get(self, booking_id: str) -> dict:
        await self.expire_no_shows()
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
        if booking["status"] not in (
            BookingStatus.PENDING.value,
            BookingStatus.NO_SHOW.value,
        ):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Booking already processed")

        sales = await self.users.get_by_id(data.sales_employee_id)
        if not sales or sales["role"] != "sales":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid sales employee")

        now = utcnow()
        existing_id = (data.existing_customer_id or "").strip() or None

        if existing_id:
            # ملف زبون موجود مسبقاً — موظف الاستقبال يحدد نوع الزيارة
            customer = await self.customers.find_one({"_id": oid(existing_id, "customer")})
            if not customer:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Customer not found")
            if not data.visit_type:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="يجب تحديد نوع الزيارة",
                )
            visit_type = data.visit_type
            customer_id = existing_id
            customer_updates: dict = {
                "sales_employee_id": data.sales_employee_id,
                "updated_at": now,
            }
            if data.notes:
                customer_updates["notes"] = data.notes
            await self.customers.update_one(
                {"_id": oid(customer_id, "customer")},
                {"$set": customer_updates},
            )
        else:
            # إنشاء ملف من هذا الحجز = أول زيارة تلقائياً
            visit_type = VisitType.FIRST
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

        visit_label = (
            "First visit — booking approved"
            if visit_type == VisitType.FIRST
            else "Follow-up visit — booking approved"
        )
        await self.visits.insert_one(
            {
                "customer_id": customer_id,
                "visit_date": now,
                "visit_type": visit_type.value,
                "notes": data.notes or visit_label,
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
                    "visit_type": visit_type.value,
                    "approved_by": reception["id"],
                    "approved_at": now,
                    "updated_at": now,
                }
            },
        )
        return await self.get(booking_id)
