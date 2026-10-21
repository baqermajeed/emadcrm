from app.schemas.common import ORMModel


class StaffReport(ORMModel):
    employee_id: str
    employee_name: str
    role: str
    bookings_count: int = 0
    customers_count: int = 0
    visits_count: int = 0
    deals_count: int = 0
    deals_total_amount: float = 0
    reservations_count: int = 0
    reservations_amount: float = 0


class ManagerDashboard(ORMModel):
    total_bookings: int
    pending_bookings: int
    approved_bookings: int
    total_customers: int
    total_visits: int
    total_deals: int
    total_deals_amount: float
    total_reservations: int
    total_reservations_amount: float
    active_reservations: int
    staff_reports: list[StaffReport]
