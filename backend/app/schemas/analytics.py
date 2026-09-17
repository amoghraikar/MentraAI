from datetime import date
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field


class TimeRangeEnum(str, Enum):
    TODAY = "today"
    SEVEN_DAYS = "7d"
    THIRTY_DAYS = "30d"


class DailyFocusMetric(BaseModel):
    date: str
    day_label: str
    study_minutes: int
    focus_score: int
    sessions_count: int


class DistractionBreakdownItem(BaseModel):
    name: str
    count: int
    percentage: int
    trend_label: str


class SubjectStudyDistribution(BaseModel):
    subject_id: str
    subject_title: str
    color_hex: str
    total_minutes: int
    sessions_count: int
    percentage: int


class GoalAnalyticsSummary(BaseModel):
    active_goals: int
    completed_goals: int
    completion_rate_percentage: int
    milestones_completed: int


class StudyStreakSummary(BaseModel):
    current_streak_days: int
    longest_streak_days: int
    total_study_days: int


class AnalyticsAiInsight(BaseModel):
    title: str
    category: str
    summary: str
    action_recommendation: str
    impact_metric: str


class AnalyticsOverviewResponse(BaseModel):
    time_range: TimeRangeEnum
    total_study_minutes: int
    total_study_time_formatted: str
    daily_average_minutes: int
    total_sessions_count: int
    completed_sessions_count: int
    interrupted_sessions_count: int
    average_session_duration_minutes: int
    average_focus_score: int
    total_distractions_count: int
    consistency_score: int
    study_time_trend_label: str
    focus_trend_label: str
    daily_trends: List[DailyFocusMetric]
    distraction_breakdown: List[DistractionBreakdownItem]
    subject_distribution: List[SubjectStudyDistribution]
    goal_summary: GoalAnalyticsSummary
    streak_summary: StudyStreakSummary
    ai_insights: List[AnalyticsAiInsight] = Field(default_factory=list)
