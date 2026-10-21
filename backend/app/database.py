from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

from app.config import get_settings

_client: AsyncIOMotorClient | None = None
_db: AsyncIOMotorDatabase | None = None


async def connect_db() -> None:
    global _client, _db
    settings = get_settings()
    _client = AsyncIOMotorClient(settings.mongodb_url)
    _db = _client[settings.database_name]
    await _ensure_indexes(_db)


async def close_db() -> None:
    global _client, _db
    if _client is not None:
        _client.close()
    _client = None
    _db = None


def get_db() -> AsyncIOMotorDatabase:
    if _db is None:
        raise RuntimeError("Database is not connected")
    return _db


async def _ensure_indexes(db: AsyncIOMotorDatabase) -> None:
    await db.users.create_index("username", unique=True)
    await db.users.create_index("role")
    await db.bookings.create_index("phone")
    await db.bookings.create_index("status")
    await db.bookings.create_index("call_center_id")
    await db.bookings.create_index("visit_date")
    await db.bookings.create_index([("status", 1), ("visit_date", -1)])
    await db.customers.create_index("phone")
    await db.customers.create_index("sales_employee_id")
    await db.customers.create_index("call_center_id")
    await db.customers.create_index("created_at")
    await db.visits.create_index("customer_id")
    await db.visits.create_index([("customer_id", 1), ("visit_date", -1)])
    await db.deals.create_index("customer_id")
    await db.deals.create_index("sales_employee_id")
    await db.deals.create_index("sale_date")
    await db.reservations.create_index("customer_id")
    await db.reservations.create_index("sales_employee_id")
    await db.reservations.create_index("reservation_date")
    await db.reservations.create_index("status")
