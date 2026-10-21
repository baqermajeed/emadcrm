from datetime import datetime, timezone

from bson import ObjectId
from fastapi import HTTPException, status


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def oid(value: str, field: str = "id") -> ObjectId:
    if not ObjectId.is_valid(value):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid {field}",
        )
    return ObjectId(value)


def serialize_doc(doc: dict | None) -> dict | None:
    if doc is None:
        return None
    result = {**doc}
    if "_id" in result:
        result["id"] = str(result.pop("_id"))
    for key, value in list(result.items()):
        if isinstance(value, ObjectId):
            result[key] = str(value)
        elif isinstance(value, list):
            result[key] = [
                str(item) if isinstance(item, ObjectId) else item for item in value
            ]
    return result


def serialize_docs(docs: list[dict]) -> list[dict]:
    return [serialize_doc(doc) for doc in docs if doc is not None]
