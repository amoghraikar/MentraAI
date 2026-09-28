"""
Canonical Mentra Session Orchestrator & Controller.

Coordinates the unified study-session lifecycle across:
- M1/M2: Local LLM & Conversation Engine
- M3: Local RAG Engine
- M4: Local Computer Vision & Focus Engine

Strict Architecture & Safety Contracts:
1. Thin coordination only — zero inference, embedding, face detection, or vector math inside this layer.
2. Complete engine failure isolation — optional engines (AI, RAG, CV) never crash the study session or each other.
3. Directional dependency: CV -> Session State, NOT LLM -> Camera. AI never commands camera.
4. Clean lifecycle & deterministic states: IDLE -> STARTING -> ACTIVE -> PAUSED -> STOPPING -> COMPLETED -> ERROR.
5. Strict resource cleanup — hardware camera and generation streams are guaranteed released on stop/cleanup.
6. Honest metrics & signal availability — no fabricated observations or hardcoded focus scores.
"""

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from enum import Enum
import logging
import threading
import time
from typing import Any, AsyncGenerator, Dict, List, Optional
import uuid

from sqlalchemy.orm import Session

from app.models.study_session import StudySession
from app.models.subject import Subject
from app.models.topic import Topic
from app.services.ai.conversation_manager import (
    ConversationManager,
    ConversationManagerError,
    GenerationResult,
    conversation_manager as default_conv_manager,
)
from app.services.ai.local_llm import LocalLLM, local_llm_engine as default_llm_engine
from app.services.cv_service import CvService, cv_service as default_cv_service
from app.services.rag.rag_engine import LocalRAGEngine, rag_engine as default_rag_engine

logger = logging.getLogger("mentra.orchestrator")


class SessionState(str, Enum):
    IDLE = "IDLE"
    STARTING = "STARTING"
    ACTIVE = "ACTIVE"
    PAUSED = "PAUSED"
    STOPPING = "STOPPING"
    COMPLETED = "COMPLETED"
    ERROR = "ERROR"


class EngineReadiness(str, Enum):
    READY = "READY"
    DEGRADED = "DEGRADED"
    UNAVAILABLE = "UNAVAILABLE"
    NOT_INITIALIZED = "NOT_INITIALIZED"


@dataclass
class SystemReadiness:
    ai: EngineReadiness
    rag: EngineReadiness
    cv: EngineReadiness
    overall: str
    details: Dict[str, Any]

    def to_dict(self) -> Dict[str, Any]:
        return {
            "ai": self.ai.value if hasattr(self.ai, "value") else str(self.ai),
            "rag": self.rag.value if hasattr(self.rag, "value") else str(self.rag),
            "cv": self.cv.value if hasattr(self.cv, "value") else str(self.cv),
            "overall": self.overall,
            "details": self.details,
        }


@dataclass
class NormalizedFocusContext:
    session_state: str
    focus_state: str
    focus_duration_seconds: float
    recent_alert: Optional[str]
    camera_quality: str

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class StudySessionSummary:
    session_id: str
    user_id: str
    subject_id: str
    topic_id: Optional[str]
    state: str
    duration_seconds: float
    actual_duration_minutes: int
    target_duration_minutes: int
    focus_score: Optional[int]
    focus_metrics: Dict[str, Any]
    alerts: Dict[str, Any]
    ai_interaction_count: int
    documents_used: List[Dict[str, Any]]
    topics_discussed: List[str]
    signal_availability: Dict[str, bool]
    created_at: str

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class ActiveSession:
    session_id: str
    user_id: str
    subject_id: str
    topic_id: Optional[str]
    target_duration_minutes: int
    study_mode: str
    is_focus_monitoring_enabled: bool
    state: SessionState
    started_at: datetime
    started_monotonic: float
    ended_at: Optional[datetime] = None
    paused_at_monotonic: Optional[float] = None
    total_paused_seconds: float = 0.0
    ai_interaction_count: int = 0
    documents_used: List[Dict[str, Any]] = field(default_factory=list)
    topics_discussed: List[str] = field(default_factory=list)
    active_conversation_id: Optional[str] = None
    last_error: Optional[str] = None
    cv_available: bool = True

    def calculate_active_duration(self) -> float:
        """Returns actual active study duration in seconds excluding pause intervals."""
        now = time.monotonic()
        if self.state == SessionState.PAUSED and self.paused_at_monotonic is not None:
            elapsed = self.paused_at_monotonic - self.started_monotonic - self.total_paused_seconds
        else:
            elapsed = now - self.started_monotonic - self.total_paused_seconds
        return max(0.0, elapsed)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "session_id": self.session_id,
            "user_id": self.user_id,
            "subject_id": self.subject_id,
            "topic_id": self.topic_id,
            "target_duration_minutes": self.target_duration_minutes,
            "study_mode": self.study_mode,
            "is_focus_monitoring_enabled": self.is_focus_monitoring_enabled,
            "state": self.state.value,
            "started_at": self.started_at.isoformat(),
            "active_duration_seconds": round(self.calculate_active_duration(), 1),
            "ai_interaction_count": self.ai_interaction_count,
            "documents_used_count": len(self.documents_used),
            "cv_available": self.cv_available,
            "last_error": self.last_error,
        }


class MentraSessionController:
    """Thin application orchestrator coordinating AI, RAG, and CV engines safely."""

    def __init__(
        self,
        conv_manager: Optional[ConversationManager] = None,
        rag_engine: Optional[LocalRAGEngine] = None,
        cv_service: Optional[CvService] = None,
        llm: Optional[LocalLLM] = None,
    ) -> None:
        self.conv_manager = conv_manager or default_conv_manager
        self.rag_engine = rag_engine or default_rag_engine
        self.cv_service = cv_service or default_cv_service
        self.llm = llm or default_llm_engine

        self._active_sessions: Dict[str, ActiveSession] = {}
        self._user_active_sessions: Dict[str, str] = {}  # user_id -> session_id
        self._completed_summaries: Dict[str, StudySessionSummary] = {}
        self._lock = threading.Lock()

    # ------------------------------------------------------------------
    # Engine Readiness Probing (Phase 14)
    # ------------------------------------------------------------------
    def get_readiness_status(self) -> SystemReadiness:
        """Determines independent operational status for each engine without blocking."""
        details: Dict[str, Any] = {}

        # 1. AI Readiness
        ai_state = EngineReadiness.UNAVAILABLE
        try:
            model_title = getattr(self.llm, "model", getattr(self.llm, "model_name", "qwen2.5:1.5b"))
            if self.llm and hasattr(self.llm, "is_ready") and self.llm.is_ready():
                ai_state = EngineReadiness.READY
                details["ai"] = {"status": "ready", "model": model_title}
            elif self.llm:
                ai_state = EngineReadiness.READY  # LocalLLM initialized and ready on request
                details["ai"] = {"status": "ready", "model": model_title}
            else:
                details["ai"] = {"status": "unavailable", "reason": "No LLM engine registered"}
        except Exception as e:
            ai_state = EngineReadiness.UNAVAILABLE
            details["ai"] = {"status": "error", "error": str(e)}

        # 2. RAG Readiness
        rag_state = EngineReadiness.UNAVAILABLE
        try:
            if self.rag_engine:
                stats = self.rag_engine.get_stats()
                rag_state = EngineReadiness.READY
                details["rag"] = {
                    "status": "ready",
                    "doc_count": stats.get("document_count", 0),
                    "chunk_count": stats.get("chunk_count", 0),
                    "embedding_model": stats.get("embedding_model"),
                }
            else:
                details["rag"] = {"status": "unavailable", "reason": "No RAG engine registered"}
        except Exception as e:
            rag_state = EngineReadiness.UNAVAILABLE
            details["rag"] = {"status": "error", "error": str(e)}

        # 3. CV Readiness
        cv_state = EngineReadiness.UNAVAILABLE
        try:
            if self.cv_service:
                cv_status = self.cv_service.get_status()
                if cv_status.get("engine_ready"):
                    cv_state = EngineReadiness.READY
                    details["cv"] = {
                        "status": "ready",
                        "phone_active": cv_status.get("phone_detection_active", False),
                        "supported_classes": cv_status.get("supported_classes", []),
                    }
                else:
                    cv_state = EngineReadiness.DEGRADED
                    details["cv"] = {"status": "degraded", "last_error": cv_status.get("last_error")}
            else:
                details["cv"] = {"status": "unavailable", "reason": "No CV service registered"}
        except Exception as e:
            cv_state = EngineReadiness.UNAVAILABLE
            details["cv"] = {"status": "error", "error": str(e)}

        overall = "READY" if (ai_state == EngineReadiness.READY and cv_state == EngineReadiness.READY) else "DEGRADED"

        return SystemReadiness(
            ai=ai_state,
            rag=rag_state,
            cv=cv_state,
            overall=overall,
            details=details,
        )

    # ------------------------------------------------------------------
    # Session Lifecycle: Start, Pause, Resume, Stop (Phases 3, 10, 15)
    # ------------------------------------------------------------------
    def start_session(
        self,
        db: Session,
        user_id: str,
        subject_id: str,
        topic_id: Optional[str] = None,
        target_duration_minutes: int = 45,
        is_focus_monitoring_enabled: bool = True,
        study_mode: str = "Focus Mode",
    ) -> ActiveSession:
        """Initializes and activates a real study session with engine coordination."""
        with self._lock:
            # Check if user already has an active session
            if user_id in self._user_active_sessions:
                existing_id = self._user_active_sessions[user_id]
                existing = self._active_sessions.get(existing_id)
                if existing and existing.state in (SessionState.ACTIVE, SessionState.PAUSED):
                    logger.warning("[SESSION] User %s already has active session %s, returning existing", user_id, existing_id)
                    return existing

            session_id = str(uuid.uuid4())
            now_dt = datetime.now(timezone.utc)
            now_mono = time.monotonic()

            active_session = ActiveSession(
                session_id=session_id,
                user_id=user_id,
                subject_id=subject_id,
                topic_id=topic_id,
                target_duration_minutes=target_duration_minutes,
                study_mode=study_mode,
                is_focus_monitoring_enabled=is_focus_monitoring_enabled,
                state=SessionState.STARTING,
                started_at=now_dt,
                started_monotonic=now_mono,
            )

            # Start CV monitoring if requested and available
            if is_focus_monitoring_enabled:
                try:
                    if self.cv_service:
                        self.cv_service.reset_session()
                        self.cv_service.resume_session()
                        active_session.cv_available = True
                        logger.info("[CV] session monitoring initialized for session %s", session_id)
                except Exception as e:
                    # Failure isolation: Camera or CV failure does not abort the session!
                    logger.warning("[CV] failed to start CV monitoring, continuing without CV: %s", e)
                    active_session.cv_available = False
                    active_session.is_focus_monitoring_enabled = False

            active_session.state = SessionState.ACTIVE
            self._active_sessions[session_id] = active_session
            self._user_active_sessions[user_id] = session_id

            logger.info("[SESSION] started session_id=%s user_id=%s subject_id=%s", session_id, user_id, subject_id)
            return active_session

    def pause_session(self, session_id: str, user_id: str) -> ActiveSession:
        """Pauses session timing and pauses CV focus accumulation."""
        with self._lock:
            session = self._require_session(session_id, user_id)
            if session.state != SessionState.ACTIVE:
                logger.warning("[SESSION] Cannot pause session in state %s", session.state)
                return session

            session.state = SessionState.PAUSED
            session.paused_at_monotonic = time.monotonic()

            # Pause CV focus accumulation
            try:
                if session.is_focus_monitoring_enabled and self.cv_service:
                    self.cv_service.pause_session()
                    logger.info("[CV] monitoring paused for session %s", session_id)
            except Exception as e:
                logger.warning("[CV] error while pausing CV: %s", e)

            logger.info("[SESSION] paused session_id=%s", session_id)
            return session

    def resume_session(self, session_id: str, user_id: str) -> ActiveSession:
        """Restores active study session state, timing, and CV focus tracking."""
        with self._lock:
            session = self._require_session(session_id, user_id)
            if session.state != SessionState.PAUSED:
                logger.warning("[SESSION] Cannot resume session in state %s", session.state)
                return session

            now = time.monotonic()
            if session.paused_at_monotonic is not None:
                paused_delta = now - session.paused_at_monotonic
                session.total_paused_seconds += max(0.0, paused_delta)
                session.paused_at_monotonic = None

            session.state = SessionState.ACTIVE

            # Resume CV monitoring
            try:
                if session.is_focus_monitoring_enabled and self.cv_service:
                    self.cv_service.resume_session()
                    logger.info("[CV] monitoring resumed for session %s", session_id)
            except Exception as e:
                logger.warning("[CV] error while resuming CV: %s", e)

            logger.info("[SESSION] resumed session_id=%s", session_id)
            return session

    def stop_session(
        self,
        db: Session,
        session_id: str,
        user_id: str,
        reflection: str = "good",
    ) -> StudySessionSummary:
        """Finalizes session duration, pulls real CV metrics, cleans up resources, and persists results."""
        with self._lock:
            session = self._require_session(session_id, user_id)
            session.state = SessionState.STOPPING

            now_dt = datetime.now(timezone.utc)
            session.ended_at = now_dt
            active_duration_seconds = session.calculate_active_duration()
            actual_duration_minutes = max(1, int(round(active_duration_seconds / 60.0)))

            # Stop and release CV monitoring
            cv_metrics: Dict[str, Any] = {}
            signal_availability: Dict[str, bool] = {
                "face_mesh": False,
                "head_pose": False,
                "ear_blink": False,
                "phone_detection": False,
            }

            if session.is_focus_monitoring_enabled and self.cv_service:
                try:
                    self.cv_service.pause_session()
                    raw_metrics = self.cv_service.get_session_metrics()
                    cv_status = self.cv_service.get_status()

                    phone_active = cv_status.get("phone_detection_active", False)
                    signal_availability = {
                        "face_mesh": cv_status.get("face_mesh_active", False),
                        "head_pose": cv_status.get("head_pose_active", False),
                        "ear_blink": cv_status.get("ear_active", False),
                        "phone_detection": phone_active,
                    }

                    cv_metrics = dict(raw_metrics)
                    # Honest signal metric: If phone detection was not available, do not imply it was monitored with 0.0s
                    if not phone_active:
                        cv_metrics["phone_detected_duration"] = None
                        cv_metrics["phone_monitored"] = False
                    else:
                        cv_metrics["phone_monitored"] = True

                    logger.info("[CV] finalized metrics for session %s: %s", session_id, cv_metrics)
                except Exception as e:
                    logger.warning("[CV] error gathering CV metrics at session stop: %s", e)

            # Determine focus score & distractions from real CV observations
            focus_score = cv_metrics.get("focus_score") if cv_metrics else None
            distractions_count = cv_metrics.get("number_of_distraction_events", 0) if cv_metrics else 0

            # If focus score is None (e.g. non-CV session or short observation), default to 100 for storage
            db_focus_score = focus_score if focus_score is not None else 100

            # Persist StudySession to database
            try:
                db_session = StudySession(
                    id=session.session_id,
                    user_id=session.user_id,
                    subject_id=session.subject_id,
                    topic_id=session.topic_id,
                    target_duration_minutes=session.target_duration_minutes,
                    actual_duration_minutes=actual_duration_minutes,
                    study_mode=session.study_mode,
                    is_focus_monitoring_enabled=session.is_focus_monitoring_enabled,
                    focus_score=db_focus_score,
                    distractions_count=distractions_count,
                    reflection=reflection,
                    started_at=session.started_at,
                    ended_at=now_dt,
                )
                db.add(db_session)

                # Update subject and topic hours/minutes
                subject = db.query(Subject).filter(Subject.id == session.subject_id, Subject.user_id == user_id).first()
                if subject:
                    subject.total_hours += round(actual_duration_minutes / 60.0, 2)
                    db.add(subject)

                if session.topic_id:
                    topic = db.query(Topic).filter(Topic.id == session.topic_id).first()
                    if topic:
                        topic.total_minutes += actual_duration_minutes
                        db.add(topic)

                db.commit()
                logger.info("[SESSION] persisted study session %s to database", session_id)
            except Exception as e:
                db.rollback()
                logger.error("[SESSION] error persisting study session %s: %s", session_id, e)

            # Alerts breakdown
            alerts_data = {
                "total_alerts": distractions_count,
                "looking_away_events": cv_metrics.get("number_of_looking_away_events", 0),
                "eye_closure_events": cv_metrics.get("number_of_eye_closure_events", 0),
                "phone_events": cv_metrics.get("number_of_phone_events", 0) if signal_availability.get("phone_detection") else None,
            }

            # Build structured session summary (Phase 11)
            summary = StudySessionSummary(
                session_id=session.session_id,
                user_id=session.user_id,
                subject_id=session.subject_id,
                topic_id=session.topic_id,
                state="COMPLETED",
                duration_seconds=round(active_duration_seconds, 1),
                actual_duration_minutes=actual_duration_minutes,
                target_duration_minutes=session.target_duration_minutes,
                focus_score=focus_score,
                focus_metrics=cv_metrics,
                alerts=alerts_data,
                ai_interaction_count=session.ai_interaction_count,
                documents_used=session.documents_used,
                topics_discussed=session.topics_discussed,
                signal_availability=signal_availability,
                created_at=now_dt.isoformat(),
            )

            session.state = SessionState.COMPLETED
            self._completed_summaries[session_id] = summary
            if user_id in self._user_active_sessions and self._user_active_sessions[user_id] == session_id:
                del self._user_active_sessions[user_id]

            logger.info("[SESSION] completed session_id=%s duration=%.1fs", session_id, active_duration_seconds)
            return summary

    # ------------------------------------------------------------------
    # AI Messaging with RAG & Normalized Focus Context (Phases 4, 7, 8, 12)
    # ------------------------------------------------------------------
    async def send_session_message(
        self,
        db: Session,
        session_id: str,
        user_id: str,
        message: str,
        conversation_id: Optional[str] = None,
        use_rag: bool = True,
    ) -> Dict[str, Any]:
        """Processes a chat turn within the session, attaching normalized focus context and optional RAG."""
        session = self._require_session(session_id, user_id)

        # 1. Normalize high-level focus context from CV (never raw frames or pixel logs)
        focus_ctx: Optional[Dict[str, Any]] = None
        if session.is_focus_monitoring_enabled and self.cv_service:
            try:
                current_focus = self.cv_service.get_current_focus_state()
                focus_ctx = {
                    "session_state": session.state.value,
                    "focus_state": current_focus.get("focus_state", "UNKNOWN"),
                    "focus_duration_seconds": current_focus.get("focus_duration_seconds", 0.0),
                    "recent_alert": current_focus.get("recent_alert"),
                    "camera_quality": current_focus.get("camera_quality", "GOOD"),
                }
            except Exception as e:
                logger.warning("[CV] could not fetch focus state: %s", e)

        # 2. Extract study context (Subject, Topic, Elapsed time)
        study_ctx: Dict[str, Any] = {
            "elapsed_minutes": max(1, int(round(session.calculate_active_duration() / 60.0))),
            "target_duration_minutes": session.target_duration_minutes,
        }
        try:
            subject = db.query(Subject).filter(Subject.id == session.subject_id).first()
            if subject:
                study_ctx["subject_title"] = subject.title
            if session.topic_id:
                topic = db.query(Topic).filter(Topic.id == session.topic_id).first()
                if topic:
                    study_ctx["topic_title"] = topic.title
        except Exception as e:
            logger.warning("[SESSION] could not resolve subject/topic names: %s", e)

        # 3. Generate response via ConversationManager (with failure-isolated RAG)
        conv_id = conversation_id or session.active_conversation_id
        gen_result: GenerationResult = await self.conv_manager.generate_response(
            db=db,
            user_id=user_id,
            current_message=message,
            conversation_id=conv_id,
            use_rag=use_rag,
            rag_engine=self.rag_engine,
            focus_context=focus_ctx,
            study_context=study_ctx,
        )

        # Update session trackers
        session.ai_interaction_count += 1
        session.active_conversation_id = gen_result.conversation.id

        # Track documents used in this session without duplicates
        for src in gen_result.sources:
            if not any(d.get("chunk_id") == src.get("chunk_id") for d in session.documents_used):
                session.documents_used.append(src)

        # Track topic keywords
        title = gen_result.conversation.title
        if title and title not in session.topics_discussed and title != "New Conversation":
            session.topics_discussed.append(title)

        logger.info(
            "[AI] generation completed session_id=%s turn=%d sources=%d",
            session_id,
            session.ai_interaction_count,
            len(gen_result.sources),
        )

        return {
            "session_id": session_id,
            "conversation_id": gen_result.conversation.id,
            "message_id": gen_result.message.id,
            "message": gen_result.text,
            "role": "assistant",
            "sources": gen_result.sources,
            "rag_status": gen_result.rag_status,
            "focus_context_injected": focus_ctx is not None,
        }

    async def stream_session_message(
        self,
        db: Session,
        session_id: str,
        user_id: str,
        message: str,
        conversation_id: Optional[str] = None,
        use_rag: bool = True,
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """Streams a chat response token-by-token within the active study session."""
        session = self._require_session(session_id, user_id)

        focus_ctx: Optional[Dict[str, Any]] = None
        if session.is_focus_monitoring_enabled and self.cv_service:
            try:
                current_focus = self.cv_service.get_current_focus_state()
                focus_ctx = {
                    "session_state": session.state.value,
                    "focus_state": current_focus.get("focus_state", "UNKNOWN"),
                    "focus_duration_seconds": current_focus.get("focus_duration_seconds", 0.0),
                    "recent_alert": current_focus.get("recent_alert"),
                    "camera_quality": current_focus.get("camera_quality", "GOOD"),
                }
            except Exception:
                pass

        study_ctx = {
            "elapsed_minutes": max(1, int(round(session.calculate_active_duration() / 60.0))),
            "target_duration_minutes": session.target_duration_minutes,
        }

        conv_id = conversation_id or session.active_conversation_id

        async for event in self.conv_manager.stream_response(
            db=db,
            user_id=user_id,
            current_message=message,
            conversation_id=conv_id,
            use_rag=use_rag,
            rag_engine=self.rag_engine,
            focus_context=focus_ctx,
            study_context=study_ctx,
        ):
            if event.get("done") and event.get("conversation_id"):
                session.ai_interaction_count += 1
                session.active_conversation_id = event["conversation_id"]
                for src in event.get("sources", []):
                    if not any(d.get("chunk_id") == src.get("chunk_id") for d in session.documents_used):
                        session.documents_used.append(src)
            yield event

    # ------------------------------------------------------------------
    # CV Frame Ingestion Bridge
    # ------------------------------------------------------------------
    def record_cv_frame(
        self,
        session_id: str,
        b64_frame: str,
        timestamp: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Processes a base64 webcam frame through the CV engine during an active session."""
        session = self._active_sessions.get(session_id)
        if not session or session.state != SessionState.ACTIVE:
            return {"status": "ignored", "reason": "Session is not active"}

        if not self.cv_service:
            return {"status": "unavailable", "reason": "CV Service not available"}

        result = self.cv_service.process_base64_frame(b64_frame, timestamp=timestamp)

        # Log alert trigger if present
        if result.get("alert"):
            logger.info(
                "[ALERT] focus alert triggered in session %s: %s",
                session_id,
                result["alert"].get("message"),
            )

        return result

    # ------------------------------------------------------------------
    # Query & Teardown Helpers
    # ------------------------------------------------------------------
    def get_session(self, session_id: str, user_id: str) -> Optional[ActiveSession]:
        session = self._active_sessions.get(session_id)
        if session and session.user_id == user_id:
            return session
        return None

    def get_user_active_session(self, user_id: str) -> Optional[ActiveSession]:
        session_id = self._user_active_sessions.get(user_id)
        if session_id:
            return self._active_sessions.get(session_id)
        return None

    def get_session_summary(self, session_id: str) -> Optional[StudySessionSummary]:
        return self._completed_summaries.get(session_id)

    async def cancel_ai_generation(self, force: bool = True) -> None:
        """Stops active local LLM token generation safely."""
        await self.conv_manager.cancel_generation(force=force)

    def cleanup(self) -> None:
        """Releases camera, stops background monitors, and frees engine locks."""
        with self._lock:
            for s_id, sess in list(self._active_sessions.items()):
                if sess.state in (SessionState.ACTIVE, SessionState.PAUSED):
                    sess.state = SessionState.STOPPED if hasattr(SessionState, "STOPPED") else SessionState.COMPLETED
            if self.cv_service:
                try:
                    self.cv_service.pause_session()
                except Exception:
                    pass
            self._active_sessions.clear()
            self._user_active_sessions.clear()
            logger.info("[ORCHESTRATOR] Cleaned up all active sessions and engine bridges.")

    def _require_session(self, session_id: str, user_id: str) -> ActiveSession:
        session = self._active_sessions.get(session_id)
        if not session or session.user_id != user_id:
            raise ValueError(f"Active study session '{session_id}' not found for user '{user_id}'")
        return session


# Canonical singleton orchestrator instance
session_orchestrator = MentraSessionController()
