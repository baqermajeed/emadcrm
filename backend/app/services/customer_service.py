import uuid
from pathlib import Path

import aiofiles
from fastapi import HTTPException, UploadFile, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.config import get_settings
from app.models.collections import Collections
from app.schemas.customer import CustomerCreate, CustomerUpdate
from app.services.user_service import UserService
from app.utils.enums import CustomerGender, CustomerStatus, HowKnewCenter
from app.utils.helpers import oid, serialize_doc, serialize_docs, utcnow

ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/gif",
    "image/heic",
    "image/heif",
    "application/pdf",
    "application/octet-stream",
}

_EXT_CONTENT_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".gif": "image/gif",
    ".heic": "image/heic",
    ".heif": "image/heif",
    ".pdf": "application/pdf",
}


class CustomerService:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db
        self.col = db[Collections.CUSTOMERS]
        self.users = UserService(db)

    async def _enrich(self, docs: list[dict]) -> list[dict]:
        ids: set[str] = set()
        for d in docs:
            if d.get("sales_employee_id"):
                ids.add(d["sales_employee_id"])
            if d.get("call_center_id"):
                ids.add(d["call_center_id"])
        names = await self.users.name_map(list(ids))
        for d in docs:
            d["sales_employee_name"] = names.get(d.get("sales_employee_id") or "")
            d["call_center_name"] = names.get(d.get("call_center_id") or "")
            d.setdefault("documents", [])
        return docs

    async def get(self, customer_id: str) -> dict:
        doc = await self.col.find_one({"_id": oid(customer_id, "customer")})
        if not doc:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer not found")
        out = serialize_doc(doc)
        return (await self._enrich([out]))[0]

    async def list_customers(
        self,
        *,
        sales_employee_id: str | None = None,
        search: str | None = None,
        page: int = 1,
        page_size: int = 50,
    ) -> tuple[list[dict], int]:
        query: dict = {}
        if sales_employee_id:
            query["sales_employee_id"] = sales_employee_id
        if search:
            query["$or"] = [
                {"name": {"$regex": search, "$options": "i"}},
                {"phone": {"$regex": search, "$options": "i"}},
            ]

        total = await self.col.count_documents(query)
        skip = (page - 1) * page_size
        cursor = self.col.find(query).sort("created_at", -1).skip(skip).limit(page_size)
        docs = serialize_docs(await cursor.to_list(page_size))
        return await self._enrich(docs), total

    async def create(self, data: CustomerCreate) -> dict:
        if data.sales_employee_id:
            sales = await self.users.get_by_id(data.sales_employee_id)
            if not sales or sales["role"] != "sales":
                raise HTTPException(status_code=400, detail="Invalid sales employee")

        now = utcnow()
        gender = data.gender or CustomerGender.MALE
        status = data.status or CustomerStatus.POTENTIAL
        how_knew = data.how_knew.value if data.how_knew else None

        doc = {
            "name": data.name.strip(),
            "phone": data.phone.strip(),
            "email": data.email.strip() if data.email else None,
            "profession": data.profession,
            "address": data.address,
            "gender": gender.value if isinstance(gender, CustomerGender) else gender,
            "how_knew": how_knew,
            "referral_buyer_name": data.referral_buyer_name,
            "sales_employee_id": data.sales_employee_id,
            "notes": data.notes,
            "status": status.value if isinstance(status, CustomerStatus) else status,
            "call_center_id": None,
            "booking_id": None,
            "documents": [],
            "created_at": now,
            "updated_at": None,
        }
        result = await self.col.insert_one(doc)
        return await self.get(str(result.inserted_id))

    async def update(self, customer_id: str, data: CustomerUpdate) -> dict:
        await self.get(customer_id)
        updates = {k: v for k, v in data.model_dump(exclude_unset=True).items() if v is not None}

        if "how_knew" in updates:
            value = updates["how_knew"]
            updates["how_knew"] = value.value if isinstance(value, HowKnewCenter) else value
            if updates["how_knew"] == HowKnewCenter.BUYER_REFERRAL.value and not updates.get(
                "referral_buyer_name"
            ):
                # allow existing referral name on partial updates
                pass

        if "gender" in updates:
            value = updates["gender"]
            updates["gender"] = value.value if isinstance(value, CustomerGender) else value

        if "status" in updates:
            value = updates["status"]
            updates["status"] = value.value if isinstance(value, CustomerStatus) else value

        if "sales_employee_id" in updates:
            sales = await self.users.get_by_id(updates["sales_employee_id"])
            if not sales or sales["role"] != "sales":
                raise HTTPException(status_code=400, detail="Invalid sales employee")

        if updates:
            updates["updated_at"] = utcnow()
            await self.col.update_one({"_id": oid(customer_id, "customer")}, {"$set": updates})
        return await self.get(customer_id)

    async def upload_document(
        self,
        customer_id: str,
        file: UploadFile,
        uploader_id: str,
        notes: str | None = None,
    ) -> dict:
        await self.get(customer_id)

        settings = get_settings()
        upload_root = Path(settings.upload_dir) / "customers" / customer_id
        upload_root.mkdir(parents=True, exist_ok=True)

        ext = Path(file.filename or "file.bin").suffix.lower() or ".bin"
        raw_type = (file.content_type or "").split(";")[0].strip().lower()
        content_type = raw_type or _EXT_CONTENT_TYPES.get(ext, "")
        if content_type == "application/octet-stream":
            content_type = _EXT_CONTENT_TYPES.get(ext, content_type)
        if content_type == "image/jpg":
            content_type = "image/jpeg"

        allowed = content_type in ALLOWED_CONTENT_TYPES or ext in _EXT_CONTENT_TYPES
        if not allowed:
            raise HTTPException(
                status_code=400,
                detail=f"File type not allowed ({raw_type or ext})",
            )
        if not content_type or content_type == "application/octet-stream":
            content_type = _EXT_CONTENT_TYPES.get(ext, "application/octet-stream")

        stored_name = f"{uuid.uuid4().hex}{ext}"
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

        clean_notes = (notes or "").strip() or None
        if clean_notes and len(clean_notes) > 300:
            clean_notes = clean_notes[:300]

        doc_meta = {
            "id": uuid.uuid4().hex,
            "filename": stored_name,
            "original_name": file.filename or stored_name,
            "content_type": content_type,
            "url": f"/uploads/customers/{customer_id}/{stored_name}",
            "uploaded_at": utcnow(),
            "uploaded_by": uploader_id,
            "notes": clean_notes,
        }
        await self.col.update_one(
            {"_id": oid(customer_id, "customer")},
            {"$push": {"documents": doc_meta}, "$set": {"updated_at": utcnow()}},
        )
        refreshed = await self.get(customer_id)
        return next(d for d in refreshed["documents"] if d["id"] == doc_meta["id"])

    async def delete_document(self, customer_id: str, document_id: str) -> dict:
        customer = await self.get(customer_id)
        target = next((d for d in customer.get("documents", []) if d["id"] == document_id), None)
        if not target:
            raise HTTPException(status_code=404, detail="Document not found")

        settings = get_settings()
        path = Path(settings.upload_dir) / "customers" / customer_id / target["filename"]
        path.unlink(missing_ok=True)

        await self.col.update_one(
            {"_id": oid(customer_id, "customer")},
            {"$pull": {"documents": {"id": document_id}}, "$set": {"updated_at": utcnow()}},
        )
        return await self.get(customer_id)
