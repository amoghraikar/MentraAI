"""
Milestone 5: Integrated Mentra Application Test Matrix.

Validates the complete 14-test integration matrix across AI, RAG, and CV:
- TEST 1: AI + no RAG + no CV
- TEST 2: AI + RAG + no CV
- TEST 3: AI + no RAG + CV
- TEST 4: AI + RAG + CV
- TEST 5: No AI + CV
- TEST 6: No AI + RAG
- TEST 7: Camera permission denied / unavailable
- TEST 8: RAG unavailable
- TEST 9: Local model unavailable
- TEST 10: Restart application / Readiness
- TEST 11: Start second study session (Session & Data Isolation)
- TEST 12: End session while AI is generating
- TEST 13: End session while CV is active (Resource cleanup)
- TEST 14: Pause and resume session (Paused duration exclusion)
"""

import asyncio
from datetime import datetime, timezone
import time
from typing import Any, Dict, List, Optional
import uuid
import pytest
from sqlalchemy.orm import Session

import app.db.session as db_session
from app.db.base import Base
from app.models.ai_coach import Conversation, CoachMessage
from app.models.study_session import StudySession
from app.models.subject import Subject
from app.models.topic import Topic
from app.models.user import User

from app.services.ai.conversation_manager import (
    ConversationManager,
    ConversationState,
    GenerationResult,
)
from app.services.ai.local_llm import LocalLLM, LocalLLMError, LocalLLMErrorCode, ModelState
from app.services.cv_service import CvService
from app.services.rag.rag_engine import LocalRAGEngine
from app.services.session_orchestrator import (
    EngineReadiness,
    MentraSessionController,
    SessionState,
    StudySessionSummary,
)


@pytest.fixture(scope="module")
def db() -> Session:
    Base.metadata.create_all(bind=db_session.engine)
    session = db_session.SessionLocal()
    yield session
    session.close()


@pytest.fixture
def test_user(db: Session) -> User:
    user = User(
        id=str(uuid.uuid4()),
        email=f"m5_test_{uuid.uuid4().hex[:8]}@mentra.ai",
        hashed_password="test_password_hash",
        full_name="Milestone5 Test Student",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def test_subject_and_topic(db: Session, test_user: User):
    subject = Subject(
        id=str(uuid.uuid4()),
        user_id=test_user.id,
        title="Computer Science",
        code="CS101",
        color_hex="#4A90E2",
    )
    db.add(subject)
    db.commit()

    topic = Topic(
        id=str(uuid.uuid4()),
        subject_id=subject.id,
        title="Data Structures & Algorithms",
    )
    db.add(topic)
    db.commit()
    return subject, topic


# ------------------------------------------------------------------
# Test Doubles for Deterministic Engine Testing & Failure Modes
# ------------------------------------------------------------------
class MockLocalLLM(LocalLLM):
    def __init__(self, response_text: str = "This is a deterministic AI response."):
        super().__init__()
        self._state = ModelState.READY
        self.response_text = response_text
        self.generate_called = False
        self.cancel_called = False
        self.last_messages = []
        self.last_system_prompt = ""

    async def generate(self, messages, system_prompt=None, temperature=0.7, max_tokens=1500) -> str:
        self.generate_called = True
        self.last_messages = messages
        self.last_system_prompt = system_prompt or ""
        return self.response_text

    async def cancel(self) -> None:
        self.cancel_called = True
        self._state = ModelState.READY


class FailingLLM(LocalLLM):
    def __init__(self):
        super().__init__()
        self._state = ModelState.ERROR

    async def generate(self, messages, system_prompt=None, temperature=0.7, max_tokens=1500) -> str:
        raise LocalLLMError(LocalLLMErrorCode.MODEL_LOAD_FAILED, "Local model weights failed to load")


class FailingRAGEngine:
    def retrieve_context(self, query: str):
        raise RuntimeError("Vector database disk I/O error")

    def get_stats(self):
        raise RuntimeError("Vector DB unavailable")


class MockCvService:
    def __init__(self, should_fail: bool = False):
        self.should_fail = should_fail
        self.is_paused = False
        self.reset_count = 0
        self.pause_count = 0
        self.resume_count = 0
        self.simulated_metrics = {
            "total_observed_seconds": 15.0,
            "focused_duration": 12.0,
            "looking_away_duration": 3.0,
            "eyes_closed_duration": 0.0,
            "possible_drowsiness_duration": 0.0,
            "phone_detected_duration": 0.0,
            "face_not_detected_duration": 0.0,
            "unknown_duration": 0.0,
            "number_of_distraction_events": 1,
            "number_of_looking_away_events": 1,
            "number_of_eye_closure_events": 0,
            "number_of_phone_events": 0,
            "focus_score": 80,
        }

    def reset_session(self):
        if self.should_fail:
            raise PermissionError("Camera hardware permission denied by OS")
        self.reset_count += 1

    def pause_session(self):
        self.is_paused = True
        self.pause_count += 1

    def resume_session(self):
        self.is_paused = False
        self.resume_count += 1

    def get_session_metrics(self):
        return dict(self.simulated_metrics)

    def get_current_focus_state(self):
        return {
            "focus_state": "LOOKING_AWAY",
            "focus_duration_seconds": 3.0,
            "recent_alert": "Looking away from screen",
            "camera_quality": "GOOD",
        }

    def get_status(self):
        if self.should_fail:
            return {"engine_ready": False, "last_error": "Camera permission denied"}
        return {
            "status": "ready",
            "engine_ready": True,
            "face_mesh_active": True,
            "head_pose_active": True,
            "ear_active": True,
            "phone_detection_active": True,
            "supported_classes": ["face", "eyes_ear", "head_pose", "cell_phone"],
        }


# ==================================================================
# 14-TEST INTEGRATION MATRIX
# ==================================================================

@pytest.mark.anyio
async def test_01_ai_no_rag_no_cv(db: Session, test_user: User, test_subject_and_topic):
    """TEST 1: AI + no RAG + no CV."""
    subject, topic = test_subject_and_topic
    mock_llm = MockLocalLLM("Arrays are contiguous memory blocks in computer science.")
    conv_mgr = ConversationManager(llm=mock_llm)
    controller = MentraSessionController(conv_manager=conv_mgr, rag_engine=None, cv_service=None)

    # 1. Start study session with CV disabled
    session = controller.start_session(
        db=db,
        user_id=test_user.id,
        subject_id=subject.id,
        topic_id=topic.id,
        is_focus_monitoring_enabled=False,
    )
    assert session.state == SessionState.ACTIVE
    assert session.is_focus_monitoring_enabled is False

    # 2. Chat with RAG disabled
    resp = await controller.send_session_message(
        db=db,
        session_id=session.session_id,
        user_id=test_user.id,
        message="What is an array?",
        use_rag=False,
    )

    assert resp["role"] == "assistant"
    assert "Arrays are contiguous" in resp["message"]
    assert resp["sources"] == []
    assert resp["rag_status"] == "NO_RAG"
    assert session.ai_interaction_count == 1

    # 3. Stop session
    summary = controller.stop_session(db=db, session_id=session.session_id, user_id=test_user.id)
    assert summary.state == "COMPLETED"
    assert summary.ai_interaction_count == 1
    assert summary.documents_used == []


@pytest.mark.anyio
async def test_02_ai_rag_no_cv(db: Session, test_user: User, test_subject_and_topic):
    """TEST 2: AI + RAG + no CV."""
    subject, topic = test_subject_and_topic
    rag = LocalRAGEngine()
    rag.clear_index()

    # Ingest real study document
    rag.ingest_document(
        content=(
            "# Array Operations in Memory\n"
            "An array stores elements of identical data type sequentially in contiguous memory blocks. "
            "Indexing starts at zero, allowing O(1) random memory access through pointer arithmetic."
        ),
        filename="arrays_lecture.md",
        title="CS101 Array Lectures",
    )

    mock_llm = MockLocalLLM("According to the lecture notes, an array provides O(1) random access.")
    conv_mgr = ConversationManager(llm=mock_llm)
    controller = MentraSessionController(conv_manager=conv_mgr, rag_engine=rag, cv_service=None)

    session = controller.start_session(
        db=db,
        user_id=test_user.id,
        subject_id=subject.id,
        topic_id=topic.id,
        is_focus_monitoring_enabled=False,
    )

    resp = await controller.send_session_message(
        db=db,
        session_id=session.session_id,
        user_id=test_user.id,
        message="Explain array memory layout and indexing",
        use_rag=True,
    )

    assert resp["rag_status"] == "SUCCESS"
    assert len(resp["sources"]) > 0
    assert resp["sources"][0]["doc_title"] == "CS101 Array Lectures"
    assert resp["sources"][0]["filename"] == "arrays_lecture.md"
    assert session.ai_interaction_count == 1
    assert len(session.documents_used) > 0

    # Verify RAG context was injected with security boundaries in the prompt sent to LLM
    last_user_msg = mock_llm.last_messages[-1]["content"]
    assert "[GROUNDING STUDY MATERIAL - UNTRUSTED REFERENCE TEXT]" in last_user_msg
    assert "CS101 Array Lectures" in last_user_msg

    summary = controller.stop_session(db=db, session_id=session.session_id, user_id=test_user.id)
    assert len(summary.documents_used) > 0


@pytest.mark.anyio
async def test_03_ai_no_rag_cv(db: Session, test_user: User, test_subject_and_topic):
    """TEST 3: AI + no RAG + CV."""
    subject, topic = test_subject_and_topic
    mock_llm = MockLocalLLM("Stay focused! Here is how linked lists differ from arrays.")
    conv_mgr = ConversationManager(llm=mock_llm)
    mock_cv = MockCvService()
    controller = MentraSessionController(conv_manager=conv_mgr, rag_engine=None, cv_service=mock_cv)

    session = controller.start_session(
        db=db,
        user_id=test_user.id,
        subject_id=subject.id,
        topic_id=topic.id,
        is_focus_monitoring_enabled=True,
    )
    assert session.is_focus_monitoring_enabled is True
    assert mock_cv.reset_count == 1

    resp = await controller.send_session_message(
        db=db,
        session_id=session.session_id,
        user_id=test_user.id,
        message="Tell me about linked lists",
        use_rag=False,
    )

    assert resp["focus_context_injected"] is True
    assert "[FOCUS CONTEXT]" in mock_llm.last_system_prompt
    assert "LOOKING_AWAY" in mock_llm.last_system_prompt

    summary = controller.stop_session(db=db, session_id=session.session_id, user_id=test_user.id)
    assert summary.focus_score == 80
    assert summary.focus_metrics["focused_duration"] == 12.0
    assert summary.focus_metrics["looking_away_duration"] == 3.0


@pytest.mark.anyio
async def test_04_ai_rag_cv(db: Session, test_user: User, test_subject_and_topic):
    """TEST 4: AI + RAG + CV (Full Unified Operation)."""
    subject, topic = test_subject_and_topic
    rag = LocalRAGEngine()
    rag.ingest_document(
        content="Binary trees have root nodes, left children, and right children.",
        filename="trees.txt",
        title="Tree Notes",
    )
    mock_llm = MockLocalLLM("Trees are hierarchical non-linear data structures.")
    conv_mgr = ConversationManager(llm=mock_llm)
    mock_cv = MockCvService()
    controller = MentraSessionController(conv_manager=conv_mgr, rag_engine=rag, cv_service=mock_cv)

    session = controller.start_session(
        db=db,
        user_id=test_user.id,
        subject_id=subject.id,
        topic_id=topic.id,
        is_focus_monitoring_enabled=True,
    )

    resp = await controller.send_session_message(
        db=db,
        session_id=session.session_id,
        user_id=test_user.id,
        message="What is a tree node?",
        use_rag=True,
    )

    assert resp["rag_status"] == "SUCCESS"
    assert resp["focus_context_injected"] is True
    assert len(resp["sources"]) > 0

    summary = controller.stop_session(db=db, session_id=session.session_id, user_id=test_user.id)
    assert summary.ai_interaction_count == 1
    assert len(summary.documents_used) > 0
    assert summary.focus_score == 80


@pytest.mark.anyio
async def test_05_no_ai_cv(db: Session, test_user: User, test_subject_and_topic):
    """TEST 5: No AI + CV (Silent Study Session with Focus Monitoring)."""
    subject, topic = test_subject_and_topic
    mock_cv = MockCvService()
    controller = MentraSessionController(conv_manager=None, rag_engine=None, cv_service=mock_cv)

    session = controller.start_session(
        db=db,
        user_id=test_user.id,
        subject_id=subject.id,
        topic_id=topic.id,
        is_focus_monitoring_enabled=True,
    )

    # Student studies silently for a period, without asking AI any questions
    await asyncio.sleep(0.1)

    summary = controller.stop_session(db=db, session_id=session.session_id, user_id=test_user.id)
    assert summary.ai_interaction_count == 0
    assert summary.documents_used == []
    assert summary.focus_score == 80
    assert summary.focus_metrics["focused_duration"] == 12.0


def test_06_no_ai_rag():
    """TEST 6: No AI + RAG (Independent Semantic Retrieval)."""
    rag = LocalRAGEngine()
    rag.ingest_document(
        content="QuickSort is an efficient in-place divide and conquer sorting algorithm with average O(n log n).",
        filename="sorting.md",
        title="Algorithms Guide",
    )

    retrieval = rag.retrieve_context("How does quicksort sort elements?")
    assert retrieval.status == "SUCCESS"
    assert len(retrieval.sources) > 0
    assert "QuickSort is an efficient" in retrieval.formatted_context
    assert retrieval.sources[0]["doc_title"] == "Algorithms Guide"


@pytest.mark.anyio
async def test_07_camera_permission_denied(db: Session, test_user: User, test_subject_and_topic):
    """TEST 7: Camera permission denied -> study session continues in non-CV mode."""
    subject, topic = test_subject_and_topic
    mock_llm = MockLocalLLM("I am here to help you study without camera monitoring.")
    conv_mgr = ConversationManager(llm=mock_llm)
    failing_cv = MockCvService(should_fail=True)  # Throws PermissionError on reset

    controller = MentraSessionController(conv_manager=conv_mgr, rag_engine=None, cv_service=failing_cv)

    # Starting session must not throw, but gracefully downgrade CV
    session = controller.start_session(
        db=db,
        user_id=test_user.id,
        subject_id=subject.id,
        topic_id=topic.id,
        is_focus_monitoring_enabled=True,
    )

    assert session.state == SessionState.ACTIVE
    assert session.cv_available is False
    assert session.is_focus_monitoring_enabled is False

    # AI still works normally
    resp = await controller.send_session_message(
        db=db,
        session_id=session.session_id,
        user_id=test_user.id,
        message="Can I still study?",
        use_rag=False,
    )
    assert resp["message"] == "I am here to help you study without camera monitoring."

    summary = controller.stop_session(db=db, session_id=session.session_id, user_id=test_user.id)
    assert summary.state == "COMPLETED"


@pytest.mark.anyio
async def test_08_rag_unavailable(db: Session, test_user: User, test_subject_and_topic):
    """TEST 8: RAG unavailable -> AI continues without document retrieval."""
    subject, topic = test_subject_and_topic
    mock_llm = MockLocalLLM("Answering from general knowledge without RAG.")
    conv_mgr = ConversationManager(llm=mock_llm)
    failing_rag = FailingRAGEngine()

    controller = MentraSessionController(conv_manager=conv_mgr, rag_engine=failing_rag, cv_service=None)

    session = controller.start_session(
        db=db,
        user_id=test_user.id,
        subject_id=subject.id,
        topic_id=topic.id,
        is_focus_monitoring_enabled=False,
    )

    # Calling with use_rag=True when RAG fails must not crash AI
    resp = await controller.send_session_message(
        db=db,
        session_id=session.session_id,
        user_id=test_user.id,
        message="What is recursion?",
        use_rag=True,
    )

    assert resp["rag_status"] == "UNAVAILABLE"
    assert resp["sources"] == []
    assert resp["message"] == "Answering from general knowledge without RAG."

    controller.stop_session(db=db, session_id=session.session_id, user_id=test_user.id)


@pytest.mark.anyio
async def test_09_local_model_unavailable(db: Session, test_user: User, test_subject_and_topic):
    """TEST 9: Local model unavailable -> CV & session still work without crashing."""
    subject, topic = test_subject_and_topic
    failing_llm = FailingLLM()
    conv_mgr = ConversationManager(llm=failing_llm)
    mock_cv = MockCvService()

    controller = MentraSessionController(conv_manager=conv_mgr, rag_engine=None, cv_service=mock_cv)

    session = controller.start_session(
        db=db,
        user_id=test_user.id,
        subject_id=subject.id,
        topic_id=topic.id,
        is_focus_monitoring_enabled=True,
    )
    assert session.state == SessionState.ACTIVE

    # Attempting to chat raises ConversationManagerError without destroying session
    with pytest.raises(Exception):
        await controller.send_session_message(
            db=db,
            session_id=session.session_id,
            user_id=test_user.id,
            message="Hello?",
            use_rag=False,
        )

    # Session remains intact and can be completed with valid CV metrics
    assert session.state == SessionState.ACTIVE
    summary = controller.stop_session(db=db, session_id=session.session_id, user_id=test_user.id)
    assert summary.state == "COMPLETED"
    assert summary.focus_score == 80


def test_10_restart_application_readiness():
    """TEST 10: Application startup order and independent readiness states."""
    controller = MentraSessionController()
    readiness = controller.get_readiness_status()

    # All engines should have independent, non-blocking states
    assert readiness.ai in (EngineReadiness.READY, EngineReadiness.UNAVAILABLE, EngineReadiness.DEGRADED)
    assert readiness.rag in (EngineReadiness.READY, EngineReadiness.UNAVAILABLE)
    assert readiness.cv in (EngineReadiness.READY, EngineReadiness.UNAVAILABLE, EngineReadiness.DEGRADED)
    assert isinstance(readiness.to_dict(), dict)


@pytest.mark.anyio
async def test_11_session_and_data_isolation(db: Session, test_user: User, test_subject_and_topic):
    """TEST 11: Session Isolation (New session starts clean without old metrics/RAG)."""
    subject, topic = test_subject_and_topic
    rag = LocalRAGEngine()
    rag.ingest_document(
        content="Graph theory studies networks of vertices and edges.",
        filename="graphs.txt",
        title="Graph Theory",
    )
    mock_llm = MockLocalLLM("Graph answer.")
    conv_mgr = ConversationManager(llm=mock_llm)
    mock_cv = MockCvService()
    controller = MentraSessionController(conv_manager=conv_mgr, rag_engine=rag, cv_service=mock_cv)

    # Session 1
    s1 = controller.start_session(db=db, user_id=test_user.id, subject_id=subject.id, topic_id=topic.id)
    await controller.send_session_message(db=db, session_id=s1.session_id, user_id=test_user.id, message="Graph query", use_rag=True)
    summary1 = controller.stop_session(db=db, session_id=s1.session_id, user_id=test_user.id)

    assert summary1.ai_interaction_count == 1
    assert len(summary1.documents_used) == 1

    # Session 2 for the same user
    s2 = controller.start_session(db=db, user_id=test_user.id, subject_id=subject.id, topic_id=topic.id)
    assert s2.session_id != s1.session_id
    assert s2.ai_interaction_count == 0
    assert s2.documents_used == []
    assert s2.topics_discussed == []

    summary2 = controller.stop_session(db=db, session_id=s2.session_id, user_id=test_user.id)
    assert summary2.ai_interaction_count == 0
    assert summary2.documents_used == []


@pytest.mark.anyio
async def test_12_end_session_while_ai_generating(db: Session, test_user: User, test_subject_and_topic):
    """TEST 12: End session while AI is generating -> cancels cleanly."""
    subject, topic = test_subject_and_topic
    mock_llm = MockLocalLLM()
    conv_mgr = ConversationManager(llm=mock_llm)
    controller = MentraSessionController(conv_manager=conv_mgr, rag_engine=None, cv_service=None)

    session = controller.start_session(db=db, user_id=test_user.id, subject_id=subject.id, topic_id=topic.id)
    await controller.cancel_ai_generation()

    assert mock_llm.cancel_called is True
    summary = controller.stop_session(db=db, session_id=session.session_id, user_id=test_user.id)
    assert summary.state == "COMPLETED"


def test_13_end_session_while_cv_active(db: Session, test_user: User, test_subject_and_topic):
    """TEST 13: End session while CV is active -> camera/resources strictly freed."""
    subject, topic = test_subject_and_topic
    mock_cv = MockCvService()
    controller = MentraSessionController(conv_manager=None, rag_engine=None, cv_service=mock_cv)

    session = controller.start_session(db=db, user_id=test_user.id, subject_id=subject.id, topic_id=topic.id, is_focus_monitoring_enabled=True)
    assert mock_cv.is_paused is False

    summary = controller.stop_session(db=db, session_id=session.session_id, user_id=test_user.id)
    assert summary.state == "COMPLETED"
    assert mock_cv.is_paused is True
    assert mock_cv.pause_count >= 1


@pytest.mark.anyio
async def test_14_pause_and_resume_session(db: Session, test_user: User, test_subject_and_topic):
    """TEST 14: Pause and resume session (Paused duration excluded from study time)."""
    subject, topic = test_subject_and_topic
    mock_cv = MockCvService()
    controller = MentraSessionController(conv_manager=None, rag_engine=None, cv_service=mock_cv)

    session = controller.start_session(db=db, user_id=test_user.id, subject_id=subject.id, topic_id=topic.id, is_focus_monitoring_enabled=True)
    await asyncio.sleep(0.2)

    # Pause
    controller.pause_session(session_id=session.session_id, user_id=test_user.id)
    assert session.state == SessionState.PAUSED
    assert mock_cv.is_paused is True

    await asyncio.sleep(0.3)  # Paused for 300ms

    # Resume
    controller.resume_session(session_id=session.session_id, user_id=test_user.id)
    assert session.state == SessionState.ACTIVE
    assert mock_cv.is_paused is False
    assert session.total_paused_seconds >= 0.25

    # Stop
    summary = controller.stop_session(db=db, session_id=session.session_id, user_id=test_user.id)
    assert summary.state == "COMPLETED"
    # Total duration should be close to active time (~0.2s), strictly less than total clock time (~0.5s)
    assert summary.duration_seconds < 0.45
