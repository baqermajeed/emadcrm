"""Seed default users for local development."""

import asyncio

from app.database import close_db, connect_db, get_db
from app.schemas.user import UserCreate
from app.services.user_service import UserService
from app.utils.enums import UserRole

DEFAULT_USERS = [
    UserCreate(
        username="callcenter",
        password="123456",
        full_name="موظف الكول سنتر",
        role=UserRole.CALL_CENTER,
        phone="07000000001",
    ),
    UserCreate(
        username="reception",
        password="123456",
        full_name="موظف الاستقبال",
        role=UserRole.RECEPTION,
        phone="07000000002",
    ),
    UserCreate(
        username="sales1",
        password="123456",
        full_name="موظف مبيعات",
        role=UserRole.SALES,
        phone="07000000003",
    ),
    UserCreate(
        username="sales2",
        password="123456",
        full_name="موظف مبيعات ثاني",
        role=UserRole.SALES,
        phone="07000000004",
    ),
    UserCreate(
        username="manager",
        password="123456",
        full_name="المدير",
        role=UserRole.MANAGER,
        phone="07000000005",
    ),
]


async def main() -> None:
    await connect_db()
    service = UserService(get_db())
    for user in DEFAULT_USERS:
        existing = await service.get_by_username(user.username)
        if existing:
            print(f"skip  {user.username}")
            continue
        created = await service.create(user)
        print(f"created {created['username']} ({created['role']})")
    await close_db()


if __name__ == "__main__":
    asyncio.run(main())
