from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import Database, require_roles
from app.schemas.report import LiveSummary, ManagerDashboard, StaffReport
from app.services.report_service import ReportService
from app.utils.enums import UserRole

router = APIRouter(prefix="/reports", tags=["Reports"])

ManagerDep = Annotated[dict, Depends(require_roles(UserRole.MANAGER))]
StaffDep = Annotated[
    dict,
    Depends(
        require_roles(
            UserRole.MANAGER,
            UserRole.RECEPTION,
            UserRole.CALL_CENTER,
            UserRole.SALES,
        )
    ),
]


@router.get("/dashboard", response_model=ManagerDashboard)
async def manager_dashboard(db: Database, _: ManagerDep):
    return await ReportService(db).dashboard()


@router.get("/staff/{employee_id}", response_model=StaffReport)
async def staff_report(employee_id: str, db: Database, _: ManagerDep):
    try:
        return await ReportService(db).staff_report(employee_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/live-summary", response_model=LiveSummary)
async def live_summary(db: Database, current_user: StaffDep):
    return await ReportService(db).live_summary(current_user)
