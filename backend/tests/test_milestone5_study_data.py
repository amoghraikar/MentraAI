"""
Milestone 5 Test Suite: Real Study Data + AI Integration.

Tests:
1. MentraStudyContext construction from real DB state and active session parameters.
2. Zero fabricated student data enforcement (handles empty history gracefully).
3. Active session and timer awareness formatting.
4. MentraIntent recognition across all specified coaching intents.
5. Context priority and prompt assembly without leakage.
6. Topic transition and conversation isolation.
7. AiCoachService chat endpoint ingestion of active study session fields.
"""

import pytest
import uuid
from datetime import datetime, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.db.base import Base
from app.models.user import User
from app.models.subject import Subject
from app.models.topic import Topic
from app.models.study_session import StudySession
from app.models.goal import Goal
from app.models.note import Note
from app.schemas.ai_coach import AiCoachChatRequest, ChatHistoryItem
from app.services.ai.mentra_context import MentraContext
from app.services.ai.conversation_engine import ConversationEngine, IntentType
from app.services.ai_coach_service import AiCoachService
from app.services.ai.local_llm import LocalLLM


@pytest.fixture
def test_db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()

    # Create dummy user
    user = User(
        id="user_test_m5",
        email="student@mentra.ai",
        full_name="Alex Student",
        hashed_password="dummy_hash_for_test",
        is_active=True,
    )
    db.add(user)

    # Create Subject & Topic
    subject = Subject(
        id="sub_dsa",
        user_id="user_test_m5",
        title="Data Structures",
        code="CS201",
        description="Core CS Algorithms and Data Structures",
    )
    db.add(subject)

    topic = Topic(
        id="top_arrays",
        subject_id="sub_dsa",
        title="Arrays & Two Pointers",
        description="Two pointer technique on linear data structures",
        total_minutes=45,
    )
    db.add(topic)
    db.commit()

    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


def test_mentra_context_with_real_active_session(test_db):
    """Verifies that real active study session parameters are accurately captured in MentraContext."""
    ctx = MentraContext.create_from_db_and_session(
        db=test_db,
        user_id="user_test_m5",
        subject_id="sub_dsa",
        topic_id="top_arrays",
        subject_title="Data Structures",
        topic_title="Arrays & Two Pointers",
        study_goal="Master two pointer technique for sorted arrays",
        elapsed_minutes=24,
        target_duration_minutes=45,
        is_session_active=True,
        focus_score=92,
        current_message="Explain this topic simply.",
    )

    assert ctx.is_session_active is True
    assert ctx.subject_title == "Data Structures"
    assert ctx.topic_title == "Arrays & Two Pointers"
    assert ctx.study_goal == "Master two pointer technique for sorted arrays"
    assert ctx.elapsed_minutes == 24
    assert ctx.target_duration_minutes == 45
    assert ctx.focus_score == 92

    formatted = ctx.format_for_prompt()
    assert "Status: Actively Studying" in formatted
    assert "Active Subject: Data Structures" in formatted
    assert "Active Topic: Arrays & Two Pointers" in formatted
    assert "Session Timer: 24 minutes elapsed (Target: 45 minutes)" in formatted
    assert "Active Goal: Master two pointer technique for sorted arrays" in formatted


def test_zero_fabricated_data_when_db_is_empty(test_db):
    """Verifies that Mentra does NOT invent statistics, streaks, or grades when DB is empty."""
    ctx = MentraContext.create_from_db_and_session(
        db=test_db,
        user_id="user_test_m5",
        subject_id=None,
        topic_id=None,
        current_message="How am I doing overall?",
    )

    assert ctx.total_sessions_completed == 0
    assert ctx.total_study_minutes == 0
    assert ctx.average_focus_score is None

    formatted = ctx.format_for_prompt()
    assert "No previous recorded sessions" in formatted
    assert "Streaks: 10" not in formatted
    assert "Grade A" not in formatted


def test_real_progress_data_from_db(test_db):
    """Verifies that actual completed sessions from the database are aggregated accurately."""
    now = datetime.now(timezone.utc)
    sess1 = StudySession(
        id=str(uuid.uuid4()),
        user_id="user_test_m5",
        subject_id="sub_dsa",
        topic_id="top_arrays",
        actual_duration_minutes=30,
        target_duration_minutes=45,
        focus_score=90,
        distractions_count=1,
        started_at=now,
        ended_at=now,
    )
    sess2 = StudySession(
        id=str(uuid.uuid4()),
        user_id="user_test_m5",
        subject_id="sub_dsa",
        topic_id="top_arrays",
        actual_duration_minutes=50,
        target_duration_minutes=45,
        focus_score=80,
        distractions_count=3,
        started_at=now,
        ended_at=now,
    )
    test_db.add_all([sess1, sess2])
    test_db.commit()

    ctx = MentraContext.create_from_db_and_session(
        db=test_db,
        user_id="user_test_m5",
        current_message="What is my progress?",
    )

    assert ctx.total_sessions_completed == 2
    assert ctx.total_study_minutes == 80
    assert ctx.average_focus_score == 85.0

    formatted = ctx.format_for_prompt()
    assert "2 completed sessions on record | 80 total study minutes | 85% average focus score" in formatted


def test_intent_detection():
    """Verifies lightweight intent recognition for all key Mentra study coaching intents."""
    assert ConversationEngine.detect_intent("Explain this concept to me").type == IntentType.EXPLAIN
    assert ConversationEngine.detect_intent("Give me a question to test my understanding").type in (IntentType.QUIZ, IntentType.PRACTICE)
    assert ConversationEngine.detect_intent("Can I get a hint please?").type == IntentType.HINT
    assert ConversationEngine.detect_intent("Why was I wrong on that previous step?").type == IntentType.REVIEW_MISTAKE
    assert ConversationEngine.detect_intent("I'm tired and losing focus").type == IntentType.MOTIVATE
    assert ConversationEngine.detect_intent("How long have I been studying?").type == IntentType.SESSION_HELP
    assert ConversationEngine.detect_intent("What am I studying right now?").type == IntentType.PROGRESS_QUESTION


def test_session_transition_updates_context(test_db):
    """Verifies that switching from Topic A to Topic B updates the active context without stale overrides."""
    # Topic A session
    ctx_a = MentraContext.create_from_db_and_session(
        db=test_db,
        user_id="user_test_m5",
        subject_id="sub_dsa",
        topic_id="top_arrays",
        subject_title="Data Structures",
        topic_title="Arrays",
        elapsed_minutes=15,
        is_session_active=True,
    )
    assert ctx_a.topic_title == "Arrays"

    # Create Topic B
    top_trees = Topic(
        id="top_trees",
        subject_id="sub_dsa",
        title="Binary Search Trees",
        description="Non-linear tree structures and traversal algorithms",
    )
    test_db.add(top_trees)
    test_db.commit()

    # Topic B session
    ctx_b = MentraContext.create_from_db_and_session(
        db=test_db,
        user_id="user_test_m5",
        subject_id="sub_dsa",
        topic_id="top_trees",
        subject_title="Data Structures",
        topic_title="Binary Search Trees",
        elapsed_minutes=5,
        is_session_active=True,
    )
    assert ctx_b.topic_title == "Binary Search Trees"
    assert ctx_b.elapsed_minutes == 5
    assert "Binary Search Trees" in ctx_b.format_for_prompt()
    assert "Arrays" not in ctx_b.format_for_prompt()


def test_conversation_isolation_with_active_session(test_db):
    """Verifies that a new chat begins with empty history while preserving the active study session."""
    ctx = MentraContext.create_from_db_and_session(
        db=test_db,
        user_id="user_test_m5",
        subject_title="Operating Systems",
        topic_title="Virtual Memory",
        is_session_active=True,
        elapsed_minutes=10,
        history=[],
        current_message="Where should we begin?",
    )

    sys_prompt, messages = ConversationEngine.prepare_llm_payload(
        current_message="Where should we begin?",
        history=[],
        context=ctx,
    )

    assert len(messages) == 1
    assert messages[0]["content"] == "Where should we begin?"
    assert "Virtual Memory" in sys_prompt


@pytest.mark.anyio
async def test_ai_coach_service_chat_ingests_session_fields(test_db):
    """Verifies that AiCoachService.chat accepts and processes the new real session fields."""
    class FakeLocalLLM:
        async def generate(self, messages, system_prompt="", temperature=0.7):
            # Assert that system prompt contains the active session info
            assert "Operating Systems" in system_prompt
            assert "Virtual Memory" in system_prompt
            assert "20 minutes elapsed (Target: 40 minutes)" in system_prompt
            return "In Virtual Memory, pages are mapped to frames in physical RAM."

    service = AiCoachService(local_llm=FakeLocalLLM())

    req = AiCoachChatRequest(
        message="Explain paging simply.",
        subject_title="Operating Systems",
        topic_title="Virtual Memory",
        study_goal="Understand page tables",
        elapsed_minutes=20,
        target_duration_minutes=40,
        is_session_active=True,
        focus_score=94,
        history=[],
    )

    resp = await service.chat(db=test_db, user_id="user_test_m5", request=req)
    assert resp.sender == "coach"
    assert "Virtual Memory" in resp.message or "paging" in resp.message
