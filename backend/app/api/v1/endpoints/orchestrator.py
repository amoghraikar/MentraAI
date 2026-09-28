"""
API Endpoints for Mentra Session Orchestrator.
Exposes study session lifecycle, RAG-grounded AI chat, normalized focus context,
and real session metrics aggregation.
"""

import json
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user_or_local, get_db
from app.models.user import User
from app.schemas.orchestrator import (
    FocusContextResponse,
    OrchestratorChatRequest,
    OrchestratorChatResponse,
    ReadinessResponse,
    RecordFrameRequest,
    SessionResponse,
    SessionSummaryResponse,
    StartSessionRequest,
    StopSessionRequest,
)
from app.services.session_orchestrator import session_orchestrator

router = APIRouter()


@router.get("/readiness", response_model=ReadinessResponse, status_code=status.HTTP_200_OK)
def get_system_readiness() -> ReadinessResponse:
    """Probes operational readiness across AI, RAG, and CV engines independently."""
    readiness = session_orchestrator.get_readiness_status()
    return ReadinessResponse(
        ai=readiness.ai.value,
        rag=readiness.rag.value,
        cv=readiness.cv.value,
        overall=readiness.overall,
        details=readiness.details,
    )


@router.post("/session/start", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
def start_study_session(
    request: StartSessionRequest,
    current_user: User = Depends(get_current_user_or_local),
    db: Session = Depends(get_db),
) -> SessionResponse:
    """Initializes and activates a new study session with optional CV and RAG."""
    session = session_orchestrator.start_session(
        db=db,
        user_id=current_user.id,
        subject_id=request.subject_id,
        topic_id=request.topic_id,
        target_duration_minutes=request.target_duration_minutes,
        is_focus_monitoring_enabled=request.is_focus_monitoring_enabled,
        study_mode=request.study_mode,
    )
    return SessionResponse(**session.to_dict())


@router.post("/session/{session_id}/pause", response_model=SessionResponse, status_code=status.HTTP_200_OK)
def pause_study_session(
    session_id: str,
    current_user: User = Depends(get_current_user_or_local),
) -> SessionResponse:
    """Pauses study session timing and suspends CV focus accumulation."""
    try:
        session = session_orchestrator.pause_session(session_id=session_id, user_id=current_user.id)
        return SessionResponse(**session.to_dict())
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@router.post("/session/{session_id}/resume", response_model=SessionResponse, status_code=status.HTTP_200_OK)
def resume_study_session(
    session_id: str,
    current_user: User = Depends(get_current_user_or_local),
) -> SessionResponse:
    """Resumes study session timing and reactivates CV focus accumulation."""
    try:
        session = session_orchestrator.resume_session(session_id=session_id, user_id=current_user.id)
        return SessionResponse(**session.to_dict())
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@router.post("/session/{session_id}/stop", response_model=SessionSummaryResponse, status_code=status.HTTP_200_OK)
def stop_study_session(
    session_id: str,
    request: StopSessionRequest = StopSessionRequest(),
    current_user: User = Depends(get_current_user_or_local),
    db: Session = Depends(get_db),
) -> SessionSummaryResponse:
    """Finalizes session, stops camera processing, aggregates metrics, and persists results."""
    try:
        summary = session_orchestrator.stop_session(
            db=db,
            session_id=session_id,
            user_id=current_user.id,
            reflection=request.reflection,
        )
        return SessionSummaryResponse(**summary.to_dict())
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@router.get("/session/active", response_model=Optional[SessionResponse], status_code=status.HTTP_200_OK)
def get_active_session(
    current_user: User = Depends(get_current_user_or_local),
) -> Optional[SessionResponse]:
    """Retrieves the active study session for the current user, if one exists."""
    session = session_orchestrator.get_user_active_session(user_id=current_user.id)
    if session and session.state.value in ("ACTIVE", "PAUSED", "STARTING"):
        return SessionResponse(**session.to_dict())
    return None


@router.get("/session/{session_id}", response_model=SessionResponse, status_code=status.HTTP_200_OK)
def get_study_session(
    session_id: str,
    current_user: User = Depends(get_current_user_or_local),
) -> SessionResponse:
    """Retrieves active session state."""
    session = session_orchestrator.get_session(session_id=session_id, user_id=current_user.id)
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    return SessionResponse(**session.to_dict())


@router.get("/session/{session_id}/summary", response_model=SessionSummaryResponse, status_code=status.HTTP_200_OK)
def get_session_summary(
    session_id: str,
    current_user: User = Depends(get_current_user_or_local),
) -> SessionSummaryResponse:
    """Retrieves final session summary and verified focus metrics."""
    summary = session_orchestrator.get_session_summary(session_id=session_id)
    if not summary:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Summary not found for this session")
    return SessionSummaryResponse(**summary.to_dict())


@router.get("/session/{session_id}/focus-context", response_model=FocusContextResponse, status_code=status.HTTP_200_OK)
def get_focus_context(
    session_id: str,
    current_user: User = Depends(get_current_user_or_local),
) -> FocusContextResponse:
    """Retrieves normalized focus context for the active session."""
    session = session_orchestrator.get_session(session_id=session_id, user_id=current_user.id)
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    cv_status = session_orchestrator.cv_service.get_current_focus_state() if session_orchestrator.cv_service else {}
    return FocusContextResponse(
        session_state=session.state.value,
        focus_state=cv_status.get("focus_state", "UNKNOWN"),
        focus_duration_seconds=cv_status.get("focus_duration_seconds", 0.0),
        recent_alert=cv_status.get("recent_alert"),
        camera_quality=cv_status.get("camera_quality", "GOOD"),
    )


@router.post("/session/{session_id}/chat", response_model=OrchestratorChatResponse, status_code=status.HTTP_200_OK)
async def chat_in_session(
    session_id: str,
    request: OrchestratorChatRequest,
    current_user: User = Depends(get_current_user_or_local),
    db: Session = Depends(get_db),
) -> OrchestratorChatResponse:
    """Sends a user query within the study session, attaching RAG and normalized focus context."""
    try:
        result = await session_orchestrator.send_session_message(
            db=db,
            session_id=session_id,
            user_id=current_user.id,
            message=request.message,
            conversation_id=request.conversation_id,
            use_rag=request.use_rag,
        )
        return OrchestratorChatResponse(**result)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Generation failed: {e}")


@router.post("/session/{session_id}/stream")
async def stream_chat_in_session(
    session_id: str,
    request: OrchestratorChatRequest,
    current_user: User = Depends(get_current_user_or_local),
    db: Session = Depends(get_db),
):
    """Streams response tokens progressively within the active study session."""
    try:
        async def event_generator():
            async for chunk in session_orchestrator.stream_session_message(
                db=db,
                session_id=session_id,
                user_id=current_user.id,
                message=request.message,
                conversation_id=request.conversation_id,
                use_rag=request.use_rag,
            ):
                yield f"data: {json.dumps(chunk)}\n\n"

        return StreamingResponse(event_generator(), media_type="text/event-stream")
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@router.post("/session/{session_id}/frame", status_code=status.HTTP_200_OK)
def record_camera_frame(
    session_id: str,
    request: RecordFrameRequest,
    current_user: User = Depends(get_current_user_or_local),
) -> dict:
    """Ingests a base64 webcam frame for temporal focus monitoring during an active session."""
    session = session_orchestrator.get_session(session_id=session_id, user_id=current_user.id)
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    return session_orchestrator.record_cv_frame(
        session_id=session_id,
        b64_frame=request.frame_b64,
        timestamp=request.timestamp,
    )
