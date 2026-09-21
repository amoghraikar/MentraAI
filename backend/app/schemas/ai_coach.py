from datetime import datetime, timezone
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


# --- Chat Schemas ---
class ChatHistoryItem(BaseModel):
    role: str = Field("user", description="user or assistant")
    content: str = Field(..., description="Message text")


class AiCoachChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000, description="Learner prompt or question")
    history: List[ChatHistoryItem] = Field(default_factory=list, description="Prior conversation history turns")
    subject_id: Optional[str] = Field(None, description="Optional active subject identifier")
    topic_id: Optional[str] = Field(None, description="Optional active topic identifier")
    active_session_id: Optional[str] = Field(None, description="Optional currently active study session ID")
    include_study_context: bool = Field(True, description="Whether to enrich prompt with user study metrics")
    
    # Real Study State from App
    subject_title: Optional[str] = Field(None, description="Active subject title from app state")
    topic_title: Optional[str] = Field(None, description="Active topic title from app state")
    study_goal: Optional[str] = Field(None, description="Active study goal from app state")
    elapsed_minutes: Optional[int] = Field(None, description="Active session elapsed minutes")
    target_duration_minutes: Optional[int] = Field(None, description="Active session target duration in minutes")
    is_session_active: Optional[bool] = Field(None, description="Whether user is currently inside an active study session")
    focus_score: Optional[int] = Field(None, description="Current session focus score")
    
    provider: Optional[str] = Field(None, description="Legacy field")
    api_key: Optional[str] = Field(None, description="Legacy field")
    model: Optional[str] = Field(None, description="Legacy field")
    custom_system_prompt: Optional[str] = Field(None, description="Custom system instructions")
    custom_endpoint_url: Optional[str] = Field(None, description="Legacy field")
    attached_material_text: Optional[str] = Field(None, description="Optional study material pasted/attached with this prompt")


class AiCoachChatResponse(BaseModel):
    id: str
    sender: str = "coach"
    message: str
    intent: Optional[str] = None
    mode: Optional[str] = None
    action: Optional[dict] = None
    action_suggestion: Optional[str] = None
    suggested_next_steps: List[str] = Field(default_factory=list)
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class AiCoachConfigRequest(BaseModel):
    provider: str = Field("auto", description="auto, gemini, openai, groq, openrouter, ollama, custom")
    api_key: Optional[str] = Field(None, description="API key")
    model: Optional[str] = Field(None, description="Model identifier")
    custom_system_prompt: Optional[str] = Field(None, description="System instructions")
    custom_endpoint_url: Optional[str] = Field(None, description="Custom base URL")


class AiCoachConfigResponse(BaseModel):
    active_provider: str
    is_cloud_connected: bool
    supported_providers: List[str]
    model: str
    custom_system_prompt: Optional[str] = None


class LocalLLMStatusResponse(BaseModel):
    state: str = Field(..., description="UNINITIALIZED, LOADING, READY, GENERATING, STOPPING, ERROR, DISPOSED")
    model: str
    status_message: str
    is_ready: bool
    last_error: Optional[str] = None


class TestKeyRequest(BaseModel):
    provider: str = Field("openai", description="openai, gemini, groq, openrouter, ollama, custom")
    api_key: Optional[str] = None
    model: Optional[str] = None
    custom_endpoint_url: Optional[str] = None


class TestKeyResponse(BaseModel):
    success: bool
    latency_ms: int
    message: str
    provider: str
    model: str


class StudyMaterialUploadRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    content: str = Field(..., min_length=1)
    filename: Optional[str] = None


class StudyMaterialUploadResponse(BaseModel):
    doc_id: str
    title: str
    filename: str
    char_count: int
    chunks_count: int
    summary_preview: str




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
