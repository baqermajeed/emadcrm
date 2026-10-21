from app.schemas.auth import LoginRequest, TokenResponse
from app.schemas.booking import BookingCreate, BookingOut, BookingUpdate
from app.schemas.customer import (
    CustomerCreateFromBooking,
    CustomerOut,
    CustomerUpdate,
    DocumentOut,
)
from app.schemas.deal import DealCreate, DealOut, DealUpdate
from app.schemas.report import ManagerDashboard, StaffReport
from app.schemas.reservation import ReservationCreate, ReservationOut, ReservationUpdate
from app.schemas.user import UserCreate, UserOut, UserUpdate
from app.schemas.visit import VisitCreate, VisitOut

__all__ = [
    "BookingCreate",
    "BookingOut",
    "BookingUpdate",
    "CustomerCreateFromBooking",
    "CustomerOut",
    "CustomerUpdate",
    "DealCreate",
    "DealOut",
    "DealUpdate",
    "DocumentOut",
    "LoginRequest",
    "ManagerDashboard",
    "ReservationCreate",
    "ReservationOut",
    "ReservationUpdate",
    "StaffReport",
    "TokenResponse",
    "UserCreate",
    "UserOut",
    "UserUpdate",
    "VisitCreate",
    "VisitOut",
]
