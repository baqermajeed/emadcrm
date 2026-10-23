from datetime import UTC, datetime

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.models.collections import Collections
from app.schemas.report import ManagerDashboard, StaffReport
from app.utils.enums import BookingStatus, ReservationStatus, UserRole


class ReportService:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db

    async def dashboard(self) -> ManagerDashboard:
        bookings = self.db[Collections.BOOKINGS]
        customers = self.db[Collections.CUSTOMERS]
        visits = self.db[Collections.VISITS]
        deals = self.db[Collections.DEALS]
        reservations = self.db[Collections.RESERVATIONS]
        users = self.db[Collections.USERS]

        total_bookings = await bookings.count_documents({})
        pending_bookings = await bookings.count_documents({"status": BookingStatus.PENDING.value})
        approved_bookings = await bookings.count_documents({"status": BookingStatus.APPROVED.value})
        total_customers = await customers.count_documents({})
        total_visits = await visits.count_documents({})
        total_deals = await deals.count_documents({})

        deals_agg = await deals.aggregate(
            [{"$group": {"_id": None, "total": {"$sum": "$total_price"}}}]
        ).to_list(1)
        total_deals_amount = float(deals_agg[0]["total"]) if deals_agg else 0.0

        total_reservations = await reservations.count_documents({})
        active_reservations = await reservations.count_documents(
            {"status": ReservationStatus.ACTIVE.value}
        )
        res_agg = await reservations.aggregate(
            [{"$group": {"_id": None, "total": {"$sum": "$down_payment"}}}]
        ).to_list(1)
        total_reservations_amount = float(res_agg[0]["total"]) if res_agg else 0.0

        staff_cursor = users.find(
            {"role": {"$in": [UserRole.CALL_CENTER.value, UserRole.SALES.value, UserRole.RECEPTION.value]},
             "is_active": True}
        )
        staff = await staff_cursor.to_list(200)
        staff_reports: list[StaffReport] = []

        for emp in staff:
            emp_id = str(emp["_id"])
            role = emp["role"]
            report = StaffReport(
                employee_id=emp_id,
                employee_name=emp["full_name"],
                role=role,
            )

            if role == UserRole.CALL_CENTER.value:
                report.bookings_count = await bookings.count_documents({"call_center_id": emp_id})
                report.customers_count = await customers.count_documents({"call_center_id": emp_id})
            elif role == UserRole.SALES.value:
                report.customers_count = await customers.count_documents({"sales_employee_id": emp_id})
                report.visits_count = await visits.count_documents({"sales_employee_id": emp_id})
                report.deals_count = await deals.count_documents({"sales_employee_id": emp_id})
                d_agg = await deals.aggregate(
                    [
                        {"$match": {"sales_employee_id": emp_id}},
                        {"$group": {"_id": None, "total": {"$sum": "$total_price"}}},
                    ]
                ).to_list(1)
                report.deals_total_amount = float(d_agg[0]["total"]) if d_agg else 0.0
                report.reservations_count = await reservations.count_documents(
                    {"sales_employee_id": emp_id}
                )
                r_agg = await reservations.aggregate(
                    [
                        {"$match": {"sales_employee_id": emp_id}},
                        {"$group": {"_id": None, "total": {"$sum": "$down_payment"}}},
                    ]
                ).to_list(1)
                report.reservations_amount = float(r_agg[0]["total"]) if r_agg else 0.0
            elif role == UserRole.RECEPTION.value:
                report.bookings_count = await bookings.count_documents({"approved_by": emp_id})
                report.visits_count = await visits.count_documents({"recorded_by": emp_id})

            staff_reports.append(report)

        staff_reports.sort(key=lambda r: (r.role, -r.deals_total_amount, -r.bookings_count))

        return ManagerDashboard(
            total_bookings=total_bookings,
            pending_bookings=pending_bookings,
            approved_bookings=approved_bookings,
            total_customers=total_customers,
            total_visits=total_visits,
            total_deals=total_deals,
            total_deals_amount=total_deals_amount,
            total_reservations=total_reservations,
            total_reservations_amount=total_reservations_amount,
            active_reservations=active_reservations,
            staff_reports=staff_reports,
        )

    async def staff_report(self, employee_id: str) -> StaffReport:
        dashboard = await self.dashboard()
        for report in dashboard.staff_reports:
            if report.employee_id == employee_id:
                return report
        raise ValueError("Employee not found in reports")

    async def live_summary(self, current_user: dict) -> dict:
        bookings = self.db[Collections.BOOKINGS]
        customers = self.db[Collections.CUSTOMERS]
        deals = self.db[Collections.DEALS]
        reservations = self.db[Collections.RESERVATIONS]

        booking_query: dict = {}
        customer_query: dict = {}
        deals_query: dict = {}
        reservations_query: dict = {}

        if current_user.get("role") == UserRole.CALL_CENTER.value:
            actor_id = current_user["id"]
            booking_query["call_center_id"] = actor_id
            customer_query["call_center_id"] = actor_id
        elif current_user.get("role") == UserRole.SALES.value:
            actor_id = current_user["id"]
            customer_query["sales_employee_id"] = actor_id
            deals_query["sales_employee_id"] = actor_id
            reservations_query["sales_employee_id"] = actor_id

        now = datetime.now(UTC)
        day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        day_end = now.replace(hour=23, minute=59, second=59, microsecond=999999)

        total_bookings = await bookings.count_documents(booking_query)
        pending_bookings = await bookings.count_documents(
            {**booking_query, "status": BookingStatus.PENDING.value}
        )
        approved_bookings = await bookings.count_documents(
            {**booking_query, "status": BookingStatus.APPROVED.value}
        )
        missed_bookings = await bookings.count_documents(
            {
                **booking_query,
                "status": {
                    "$in": [BookingStatus.CANCELLED.value, BookingStatus.NO_SHOW.value]
                },
            }
        )
        today_bookings = await bookings.count_documents(
            {
                **booking_query,
                "visit_date": {"$gte": day_start, "$lte": day_end},
            }
        )
        total_confirmed_visits = approved_bookings
        today_confirmed_visits = await bookings.count_documents(
            {
                **booking_query,
                "status": BookingStatus.APPROVED.value,
                "visit_date": {"$gte": day_start, "$lte": day_end},
            }
        )

        total_customers = await customers.count_documents(customer_query)
        total_deals = await deals.count_documents(deals_query)
        active_reservations = await reservations.count_documents(
            {**reservations_query, "status": ReservationStatus.ACTIVE.value}
        )

        return {
            "total_bookings": total_bookings,
            "pending_bookings": pending_bookings,
            "approved_bookings": approved_bookings,
            "missed_bookings": missed_bookings,
            "today_bookings": today_bookings,
            "total_confirmed_visits": total_confirmed_visits,
            "today_confirmed_visits": today_confirmed_visits,
            "total_customers": total_customers,
            "total_deals": total_deals,
            "active_reservations": active_reservations,
        }
