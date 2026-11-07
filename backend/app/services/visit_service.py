from datetime import UTC, datetime

from fastapi import HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.models.collections import Collections
from app.schemas.visit import VisitCreate, VisitUpdate
from app.services.user_service import UserService
from app.utils.enums import VisitType
from app.utils.helpers import oid, serialize_doc, serialize_docs, utcnow


class VisitService:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db
        self.col = db[Collections.VISITS]
        self.customers = db[Collections.CUSTOMERS]
        self.users = UserService(db)

    async def _customer_map(self, customer_ids: list[str]) -> dict[str, dict]:
        unique = [i for i in dict.fromkeys(customer_ids) if i]
        if not unique:
            return {}
        cursor = self.customers.find(
            {"_id": {"$in": [oid(i, "customer") for i in unique]}},
            {
                "name": 1,
                "phone": 1,
                "address": 1,
                "call_center_id": 1,
                "sales_employee_id": 1,
            },
        )
        return {str(c["_id"]): c for c in await cursor.to_list(len(unique))}

    async def _enrich(self, docs: list[dict]) -> list[dict]:
        ids: set[str] = set()
        customer_ids: list[str] = []
        for d in docs:
            if d.get("sales_employee_id"):
                ids.add(d["sales_employee_id"])
            if d.get("recorded_by"):
                ids.add(d["recorded_by"])
            if d.get("customer_id"):
                customer_ids.append(d["customer_id"])

        customers = await self._customer_map(customer_ids)
        for c in customers.values():
            if c.get("call_center_id"):
                ids.add(str(c["call_center_id"]))

        profiles = await self.users.profile_map(list(ids))
        for d in docs:
            sales = profiles.get(d.get("sales_employee_id") or "", {})
            recorded = profiles.get(d.get("recorded_by") or "", {})
            customer = customers.get(d.get("customer_id") or "", {})
            call_center_id = str(customer.get("call_center_id") or "") or None
            call_center = profiles.get(call_center_id or "", {})

            d["sales_employee_name"] = sales.get("full_name")
            d["sales_employee_avatar_url"] = sales.get("avatar_url")
            d["recorded_by_name"] = recorded.get("full_name")
            d["recorded_by_avatar_url"] = recorded.get("avatar_url")
            d["customer_name"] = customer.get("name")
            d["customer_phone"] = customer.get("phone")
            d["customer_address"] = customer.get("address")
            d["call_center_id"] = call_center_id
            d["call_center_name"] = call_center.get("full_name")
            d["call_center_avatar_url"] = call_center.get("avatar_url")
            if not d.get("visit_type"):
                d["visit_type"] = None
        return docs

    async def create(self, data: VisitCreate, actor: dict) -> dict:
        customer = await self.customers.find_one({"_id": oid(data.customer_id, "customer")})
        if not customer:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer not found")

        sales_id = data.sales_employee_id or str(customer.get("sales_employee_id") or "")
        if actor.get("role") == "sales":
            if str(customer.get("sales_employee_id") or "") != actor.get("id"):
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your customer")
            sales_id = actor["id"]

        now = utcnow()
        visit_type = data.visit_type
        if visit_type is None:
            prior = await self.col.count_documents({"customer_id": data.customer_id})
            visit_type = VisitType.FOLLOW_UP if prior > 0 else VisitType.FIRST

        doc = {
            "customer_id": data.customer_id,
            "visit_date": data.visit_date or now,
            "notes": data.notes,
            "visit_type": visit_type.value,
            "sales_employee_id": sales_id or None,
            "recorded_by": actor["id"],
            "created_at": now,
        }
        result = await self.col.insert_one(doc)
        doc["_id"] = result.inserted_id
        out = serialize_doc(doc)
        return (await self._enrich([out]))[0]

    async def list_visits(
        self,
        *,
        search: str | None = None,
        from_date: str | None = None,
        to_date: str | None = None,
        call_center_id: str | None = None,
        sales_employee_id: str | None = None,
        sort_dir: str = "desc",
        page: int = 1,
        page_size: int = 50,
    ) -> tuple[list[dict], int]:
        query: dict = {}

        if sales_employee_id:
            query["sales_employee_id"] = sales_employee_id

        customer_filter: dict = {}
        if call_center_id:
            customer_filter["call_center_id"] = call_center_id
        if search:
            customer_filter["$or"] = [
                {"name": {"$regex": search, "$options": "i"}},
                {"phone": {"$regex": search, "$options": "i"}},
                {"address": {"$regex": search, "$options": "i"}},
            ]
        if customer_filter:
            cursor = self.customers.find(customer_filter, {"_id": 1})
            customer_ids = [str(c["_id"]) for c in await cursor.to_list(20000)]
            if not customer_ids:
                return [], 0
            query["customer_id"] = {"$in": customer_ids}

        date_clause = self._build_dual_date_clause(
            field="visit_date",
            from_raw=from_date,
            to_raw=to_date,
        )
        if date_clause:
            query.update(date_clause)

        total = await self.col.count_documents(query)
        skip = (page - 1) * page_size
        sort_value = -1 if sort_dir != "asc" else 1
        cursor = self.col.find(query).sort("visit_date", sort_value).skip(skip).limit(page_size)
        docs = serialize_docs(await cursor.to_list(page_size))
        return await self._enrich(docs), total

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
