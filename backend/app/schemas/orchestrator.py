"""
Pydantic schemas for the Mentra Session Orchestrator API.
"""

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field


class StartSessionRequest(BaseModel):
    subject_id: str = Field(..., description="Active subject identifier")
    topic_id: Optional[str] = Field(None, description="Active topic identifier")
    target_duration_minutes: int = Field(45, ge=1, le=480, description="Target duration in minutes")
    is_focus_monitoring_enabled: bool = Field(True, description="Enable local CV focus monitoring")
    study_mode: str = Field("Focus Mode", description="Study mode name")


class StopSessionRequest(BaseModel):
    reflection: str = Field("good", description="Student self-reflection (good, ok, distracted)")


class SessionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    session_id: str
    user_id: str
    subject_id: str
    topic_id: Optional[str] = None
    target_duration_minutes: int
    study_mode: str
    is_focus_monitoring_enabled: bool
    state: str
    started_at: str
    active_duration_seconds: float
    ai_interaction_count: int
    documents_used_count: int
    cv_available: bool
    last_error: Optional[str] = None


class OrchestratorChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4000, description="User query or input")
    conversation_id: Optional[str] = Field(None, description="Optional active conversation container ID")
    use_rag: bool = Field(True, description="Whether to perform local RAG retrieval")


class SourceCitation(BaseModel):
    doc_id: str
    doc_title: str
    filename: str
    page_number: Optional[int] = None
    section_heading: Optional[str] = None
    chunk_id: str
    chunk_index: int
    similarity_score: float


class OrchestratorChatResponse(BaseModel):
    session_id: str
    conversation_id: str
    message_id: str
    message: str
    role: str = "assistant"
    sources: List[Dict[str, Any]] = Field(default_factory=list)
    rag_status: str
    focus_context_injected: bool


class FocusContextResponse(BaseModel):
    session_state: str
    focus_state: str
    focus_duration_seconds: float
    recent_alert: Optional[str] = None
    camera_quality: str


class SessionSummaryResponse(BaseModel):
    session_id: str
    user_id: str
    subject_id: str
    topic_id: Optional[str] = None
    state: str
    duration_seconds: float
    actual_duration_minutes: int
    target_duration_minutes: int
    focus_score: Optional[int] = None
    focus_metrics: Dict[str, Any] = Field(default_factory=dict)
    alerts: Dict[str, Any] = Field(default_factory=dict)
    ai_interaction_count: int
    documents_used: List[Dict[str, Any]] = Field(default_factory=list)
    topics_discussed: List[str] = Field(default_factory=list)
    signal_availability: Dict[str, bool] = Field(default_factory=dict)
    created_at: str


class ReadinessResponse(BaseModel):
    ai: str
    rag: str
    cv: str
    overall: str
    details: Dict[str, Any] = Field(default_factory=dict)


class RecordFrameRequest(BaseModel):
    frame_b64: str = Field(..., description="Base64 encoded JPEG or PNG webcam frame")
    timestamp: Optional[float] = Field(None, description="Monotonic or epoch frame capture timestamp")
