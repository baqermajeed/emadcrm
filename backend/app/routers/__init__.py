from fastapi import APIRouter

from app.routers import auth, bookings, customers, deals, reports, reservations, users, visits

api_router = APIRouter(prefix="/api")
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(bookings.router)
api_router.include_router(customers.router)
api_router.include_router(visits.router)
api_router.include_router(deals.router)
api_router.include_router(reservations.router)
api_router.include_router(reports.router)
