from datetime import datetime, timezone
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


# --- Chat Schemas ---
class AiCoachChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000, description="Learner prompt or question")
    subject_id: Optional[str] = Field(None, description="Optional active subject identifier")
    topic_id: Optional[str] = Field(None, description="Optional active topic identifier")
    include_study_context: bool = Field(True, description="Whether to enrich prompt with user study metrics")


class AiCoachChatResponse(BaseModel):
    id: str
    sender: str = "coach"
    message: str
    action_suggestion: Optional[str] = None
    suggested_next_steps: List[str] = Field(default_factory=list)
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


# --- Topic Explanation Schemas ---
class AiCoachExplainRequest(BaseModel):
    concept_name: str = Field(..., min_length=1, max_length=255)
    subject_id: Optional[str] = None
    topic_id: Optional[str] = None
    difficulty_level: str = Field("intermediate", description="beginner, intermediate, or advanced")
    student_notes_context: Optional[str] = None


class AiCoachExplainResponse(BaseModel):
    concept_name: str
    summary: str
    key_points: List[str] = Field(default_factory=list)
    analogy: Optional[str] = None
    practice_question: Optional[str] = None
    recommended_duration_minutes: int = 15


# --- Real-time Intervention Schemas ---
class AiCoachInterventionRequest(BaseModel):
    subject_title: str
    topic_title: str
    elapsed_minutes: int = Field(..., ge=0)
    distractions_count: int = Field(0, ge=0)
    trigger_reason: str = Field("repeated_distraction", description="drowsiness, repeated_distraction, long_session")
    session_id: Optional[str] = None


class AiCoachInterventionResponse(BaseModel):
    should_intervene: bool = True
    intervention_title: str
    intervention_message: str
    suggested_action: str = Field("micro_stretch", description="take_break, micro_stretch, switch_topic, hydrate")
    cooldown_seconds: int = 30


# --- Post-Session Reflection Schemas ---
class AiCoachSessionAnalysisRequest(BaseModel):
    session_id: str
    subject_title: str
    topic_title: str
    actual_duration_minutes: int = Field(..., ge=0)
    target_duration_minutes: int = Field(..., ge=0)
    focus_score: int = Field(..., ge=0, le=100)
    distractions_count: int = Field(0, ge=0)
    reflection: str = "good"


class AiCoachSessionAnalysisResponse(BaseModel):
    session_id: str
    overall_feedback: str
    focus_rating: str = "Strong"  # Exceptional, Strong, Moderate, Needs Recovery
    what_went_well: List[str] = Field(default_factory=list)
    areas_for_growth: List[str] = Field(default_factory=list)
    recommended_next_action: str


# --- Study Plan Schemas ---
class AiCoachStudyPlanTask(BaseModel):
    day: int
    topic_name: str
    duration_minutes: int
    study_mode: str = "Focus Mode"
    key_objective: str


class AiCoachStudyPlanRequest(BaseModel):
    subject_id: str
    goal_title: str
    available_daily_minutes: int = Field(45, ge=10, le=360)
    target_completion_days: int = Field(7, ge=1, le=60)
    goal_id: Optional[str] = None


class AiCoachStudyPlanResponse(BaseModel):
    plan_title: str
    total_days: int
    estimated_total_hours: float
    strategy_summary: str
    daily_tasks: List[AiCoachStudyPlanTask] = Field(default_factory=list)


# --- Insights Schemas ---
class CoachInsightResponse(BaseModel):
    id: str
    title: str
    category: str
    summary: str
    action_recommendation: str
    impact_metric: str

    model_config = ConfigDict(from_attributes=True)
