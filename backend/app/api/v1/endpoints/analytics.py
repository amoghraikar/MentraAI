from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.core.dependencies import get_current_user_or_local, get_db
from app.models.user import User
from app.schemas.analytics import AnalyticsOverviewResponse, TimeRangeEnum
from app.services.analytics_service import analytics_service

router = APIRouter()


@router.get("/overview", response_model=AnalyticsOverviewResponse)
def get_analytics_overview(
    range: TimeRangeEnum = Query(TimeRangeEnum.SEVEN_DAYS, description="Analytics time window: today, 7d, 30d"),
    timezone_offset: float = Query(0.0, description="Local user timezone offset in hours (e.g. +5.5, -4.0)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_or_local),
) -> AnalyticsOverviewResponse:
    """
    Get comprehensive study analytics, session metrics, focus telemetry,
    subject distribution, goal progress, and AI study insights scoped to the authenticated user.
    """
    return analytics_service.get_overview(
        db=db,
        user_id=current_user.id,
        time_range=range,
        tz_offset_hours=timezone_offset,
    )
