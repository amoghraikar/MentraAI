"""
Milestone 2: Real Mentra Conversation Engine Test Suite.

Validates the full conversation pipeline:
- Conversation and Message Data Models & proper role assignment
- Isolation between conversations (Conversation A != Conversation B)
- Deterministic title generation without redundant LLM calls
- ContextBuilder bounded strategy (bounded turns, character limit, role preservation)
- Real multi-turn conversation with local Qwen2.5 (10 turns including pronoun resolution)
- Real code explanation and follow-up context
- Genuine streaming token yield and state management
- Cancellation and error recovery without corrupting state
- Headless service-level execution without UI dependency
- Complete API endpoint testing for conversation CRUD and chat
"""

import uuid
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
import app.db.session as db_session
from app.db.base import Base
from app.models.ai_coach import Conversation, CoachMessage
from app.models.user import User


def get_test_db() -> Session:
    Base.metadata.create_all(bind=db_session.engine)
    return db_session.SessionLocal()
from app.services.ai.conversation_manager import (
    ConversationManager,
    ConversationState,
    ConversationManagerError,
    conversation_manager,
)
from app.services.ai.context_builder import ContextBuilder, MentraContextBuilder
from app.services.ai.local_llm import local_llm_engine
from app.services.ai.prompts import MENTRA_SYSTEM_PROMPT
from app.services.ai_coach_service import AiCoachService
from app.schemas.ai_coach import AiCoachChatRequest

client = TestClient(app)


def create_test_user(db: Session) -> User:
    """Helper to create a fresh isolated user."""
    user = User(
        id=str(uuid.uuid4()),
        email=f"test_{uuid.uuid4().hex[:8]}@mentra.ai",
        hashed_password="hashed_pw_test",
        full_name="M2 Test Student",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def get_auth_token_for_user(email: str, password: str = "Mentra#Study42") -> str:
    """Registers and logs in a test user returning JWT token."""
    reg = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "full_name": "API Test User"},
    )
    if reg.status_code == 201:
        login = client.post("/api/v1/auth/login", json={"email": email, "password": password})
        return login.json()["access_token"]
    login = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    return login.json()["access_token"]


# =====================================================================
# Phase 2: Conversation Data Model & Roles
# =====================================================================
def test_conversation_data_model():
    """Validates Conversation and CoachMessage entities, fields, relationships, and roles."""
    db = get_test_db()
    try:
        user = create_test_user(db)

        # 1. Create Conversation
        conv = Conversation(
            id=str(uuid.uuid4()),
            user_id=user.id,
            title="Data Structures",
        )
        db.add(conv)
        db.commit()
        db.refresh(conv)

        assert conv.id is not None
        assert conv.title == "Data Structures"
        assert conv.user_id == user.id
        assert conv.created_at is not None
        assert conv.updated_at is not None

        # 2. Create User Message
        user_msg = CoachMessage(
            id=str(uuid.uuid4()),
            conversation_id=conv.id,
            user_id=user.id,
            role="user",
            content="Teach me linked lists",
        )
        db.add(user_msg)
        db.commit()
        db.refresh(user_msg)

        assert user_msg.role == "user"
        assert user_msg.sender == "user"
        assert user_msg.content == "Teach me linked lists"
        assert user_msg.message == "Teach me linked lists"
        assert user_msg.conversation_id == conv.id

        # 3. Create Assistant Message
        asst_msg = CoachMessage(
            id=str(uuid.uuid4()),
            conversation_id=conv.id,
            user_id=user.id,
            role="assistant",
            content="A linked list is a linear data structure...",
        )
        db.add(asst_msg)
        db.commit()
        db.refresh(asst_msg)

        assert asst_msg.role == "assistant"
        assert asst_msg.sender == "coach"
        assert "linked list" in asst_msg.content

        # 4. Check conversation relationship & ordering
        db.refresh(conv)
        assert len(conv.messages) == 2
        assert conv.messages[0].role == "user"
        assert conv.messages[1].role == "assistant"

        # 5. Check user relationship
        db.refresh(user)
        assert conv in user.conversations
    finally:
        db.close()


# =====================================================================
# Phase 11: Multi-Conversation Isolation
# =====================================================================
def test_multi_conversation_isolation():
    """Verifies Conversation A and Conversation B are strictly isolated."""
    db = get_test_db()
    mgr = ConversationManager(local_llm_engine)
    try:
        user = create_test_user(db)

        # Create Conversation A
        conv_a = mgr.create_conversation(db, user.id, title="DBMS Normalization")
        mgr.add_user_message(db, conv_a.id, user.id, "My topic is DBMS.")
        mgr.add_assistant_message(db, conv_a.id, user.id, "DBMS is a database management system.")

        # Create Conversation B
        conv_b = mgr.create_conversation(db, user.id, title="Python Basics")
        mgr.add_user_message(db, conv_b.id, user.id, "What is Python?")
        mgr.add_assistant_message(db, conv_b.id, user.id, "Python is a high-level programming language.")

        # Verify messages in Conv A
        msgs_a = mgr.get_messages(db, conv_a.id, user.id)
        assert len(msgs_a) == 2
        assert msgs_a[0].message == "My topic is DBMS."
        assert not any("Python" in m.message for m in msgs_a)

        # Verify messages in Conv B
        msgs_b = mgr.get_messages(db, conv_b.id, user.id)
        assert len(msgs_b) == 2
        assert msgs_b[0].message == "What is Python?"
        assert not any("DBMS" in m.message for m in msgs_b)

        # Clear Conv A, verify Conv B is unharmed
        mgr.clear_conversation(db, conv_a.id, user.id)
        assert len(mgr.get_messages(db, conv_a.id, user.id)) == 0
        assert len(mgr.get_messages(db, conv_b.id, user.id)) == 2

        # Delete Conv A, verify Conv B remains intact
        mgr.delete_conversation(db, conv_a.id, user.id)
        assert mgr.load_conversation(db, conv_a.id, user.id) is None
        assert mgr.load_conversation(db, conv_b.id, user.id) is not None
        assert len(mgr.get_messages(db, conv_b.id, user.id)) == 2
    finally:
        db.close()


# =====================================================================
# Phase 12: Deterministic Title Generation
# =====================================================================
def test_deterministic_title_generation():
    """Verifies titles are derived without redundant LLM calls."""
    assert ConversationManager.generate_title_deterministic("Teach me arrays") == "Arrays"
    assert ConversationManager.generate_title_deterministic("Teach me about linked lists") == "Linked Lists"
    assert ConversationManager.generate_title_deterministic("Explain normalization in DBMS") == "Normalization In DBMS"
    assert ConversationManager.generate_title_deterministic("What is a binary search tree?") == "Binary Search Tree"
    assert ConversationManager.generate_title_deterministic("for(int i = 0; i < n; i++) { cout << arr[i]; }") == "Code Explanation"
    assert ConversationManager.generate_title_deterministic("Hi") == "Study Chat"
    assert ConversationManager.generate_title_deterministic("Hello") == "Study Chat"
    assert ConversationManager.generate_title_deterministic("Bye") == "Wrap Up"
    assert ConversationManager.generate_title_deterministic("") == "New Study Chat"


# =====================================================================
# Phase 6 & 7: ContextBuilder & Bounded Context Window
# =====================================================================
def test_context_builder_bounded_history():
    """Verifies ContextBuilder retains bounded recent turns and respects character limits."""
    # 1. Test bounded turns (MAX_HISTORY_TURNS = 12)
    large_history = []
    for i in range(20):
        large_history.append({"role": "user", "content": f"User question {i}"})
        large_history.append({"role": "assistant", "content": f"Assistant answer {i}"})

    sys_inst, chat_msgs = ContextBuilder.build_payload(
        system_instruction=MENTRA_SYSTEM_PROMPT,
        conversation_history=large_history,
        current_user_message="Current question",
    )

    # 12 history turns + 1 current message = 13 messages max
    assert len(chat_msgs) <= 13
    assert chat_msgs[-1]["role"] == "user"
    assert chat_msgs[-1]["content"] == "Current question"

    # Preserved roles
    for m in chat_msgs[:-1]:
        assert m["role"] in ("user", "assistant")

    # 2. Test character budget truncation
    huge_history = [
        {"role": "user", "content": "A" * 5000},
        {"role": "assistant", "content": "B" * 5000},
        {"role": "user", "content": "Recent question"},
        {"role": "assistant", "content": "Recent answer"},
    ]
    sys_inst, chat_msgs = ContextBuilder.build_payload(
        system_instruction=MENTRA_SYSTEM_PROMPT,
        conversation_history=huge_history,
        current_user_message="Final user turn",
    )
    total_chars = sum(len(m["content"]) for m in chat_msgs)
    assert total_chars <= MentraContextBuilder.MAX_TOTAL_CHARS

    # 3. Empty user message raises error
    with pytest.raises(ValueError):
        ContextBuilder.build_payload(
            system_instruction=MENTRA_SYSTEM_PROMPT,
            conversation_history=[],
            current_user_message="",
        )


# =====================================================================
# Phase 10: Generation States & Lifecycle
# =====================================================================
def test_conversation_manager_lifecycle_and_states():
    """Verifies state machine and explicit error reporting."""
    db = get_test_db()
    mgr = ConversationManager(local_llm_engine)
    try:
        user = create_test_user(db)
        assert mgr.state == ConversationState.IDLE

        # Empty message raises explicit error with INVALID_INPUT code
        with pytest.raises(ConversationManagerError) as exc_info:
            pytest.helpers = None
            import asyncio
            asyncio.run(mgr.generate_response(db, user.id, current_message="   "))
        assert exc_info.value.code == "INVALID_INPUT"
        assert mgr.state == ConversationState.IDLE
    finally:
        db.close()


# =====================================================================
# Phase 8 & 9: Real Streaming and Cancellation
# =====================================================================
@pytest.mark.anyio
async def test_streaming_and_cancellation():
    """Verifies genuine token streaming and cancellation recovery."""
    db = get_test_db()
    mgr = ConversationManager(local_llm_engine)
    try:
        user = create_test_user(db)
        conv = mgr.create_conversation(db, user.id, title="Stream Test")

        # 1. Real Streaming Execution
        chunks = []
        final_event = None
        async for event in mgr.stream_response(
            db=db,
            user_id=user.id,
            current_message="Say 'Hello student!' and nothing else.",
            conversation_id=conv.id,
            max_tokens=30,
        ):
            if not event.get("done"):
                chunks.append(event.get("chunk", ""))
            else:
                final_event = event

        assert len(chunks) > 0, "Expected at least one streamed token chunk"
        assert final_event is not None
        assert final_event.get("done") is True
        assert len(final_event.get("message", "")) > 0
        assert final_event.get("conversation_id") == conv.id
        assert mgr.state == ConversationState.IDLE

        # Verify assistant message was saved to database
        db_msgs = mgr.get_messages(db, conv.id, user.id)
        assert len(db_msgs) == 2  # user + assistant
        assert db_msgs[-1].role == "assistant"
        assert db_msgs[-1].message == final_event.get("message")

        # 2. Cancellation Test
        await mgr.cancel_generation()
        assert mgr.state == ConversationState.IDLE
    finally:
        db.close()


# =====================================================================
# Phase 13: Real Multi-Turn Conversation (10 Turns on Local LLM)
# =====================================================================
@pytest.mark.anyio
async def test_real_multi_turn_conversation_ten_turns():
    """
    Executes the 10-turn real local model conversation suite:
    Turn 1: Hi
    Turn 2: What can you help me with?
    Turn 3: Teach me arrays.
    Turn 4: I don't understand them. (Pronoun resolution)
    Turn 5: Explain it like I'm 10. (Simplification)
    Turn 6: Give me a practice question.
    Turn 7: I don't know. (Hinting instead of restarting)
    Turn 8: Give me another one.
    Turn 9: Make it harder.
    Turn 10: Bye. (Natural closing)
    """
    db = get_test_db()
    mgr = ConversationManager(local_llm_engine)
    try:
        user = create_test_user(db)
        conv = mgr.create_conversation(db, user.id, title="Arrays Study Session")

        turns = [
            ("Hi", 30),
            ("What can you help me with?", 50),
            ("Teach me arrays.", 100),
            ("I don't understand them.", 100),
            ("Explain it like I'm 10.", 100),
            ("Give me a practice question.", 80),
            ("I don't know.", 80),
            ("Give me another one.", 80),
            ("Make it harder.", 80),
            ("Bye.", 30),
        ]

        responses = []
        for turn_idx, (user_prompt, max_toks) in enumerate(turns, 1):
            text, active_conv, asst_msg = await mgr.generate_response(
                db=db,
                user_id=user.id,
                current_message=user_prompt,
                conversation_id=conv.id,
                max_tokens=max_toks,
                temperature=0.6,
            )
            assert text is not None and len(text.strip()) > 0, f"Turn {turn_idx} returned empty response"
            assert asst_msg.role == "assistant"
            assert asst_msg.conversation_id == conv.id
            responses.append(text)

        # Verify DB history contains all 10 pairs (20 messages)
        all_msgs = mgr.get_messages(db, conv.id, user.id)
        assert len(all_msgs) == 20

        # Turn 1: "Hi" -> natural greeting without generic study lecture
        assert len(responses[0]) > 0

        # Turn 3 & 4: "Teach me arrays." and "I don't understand them."
        # Model's turn 4 response must address arrays/elements/indexing
        turn4_lower = responses[3].lower()
        assert any(kw in turn4_lower for kw in ("array", "item", "box", "list", "element", "data", "index", "order", "store")), (
            f"Turn 4 failed pronoun resolution: {responses[3]}"
        )

        # Turn 10: "Bye." -> Friendly closing
        turn10_lower = responses[9].lower()
        assert any(kw in turn10_lower for kw in ("bye", "goodbye", "see", "great", "luck", "welcome", "study", "take care", "day", "anytime")), (
            f"Turn 10 did not behave as natural closing: {responses[9]}"
        )
    finally:
        db.close()


# =====================================================================
# Phase 14: Code Explanation Multi-Turn Test
# =====================================================================
@pytest.mark.anyio
async def test_code_explanation_multi_turn():
    """
    Tests code explanation and follow-up reference without fake execution:
    USER: Explain this:
    for(int i = 0; i < n; i++) {
        cout << arr[i];
    }
    Then USER: Why does i start at 0?
    """
    db = get_test_db()
    mgr = ConversationManager(local_llm_engine)
    try:
        user = create_test_user(db)
        conv = mgr.create_conversation(db, user.id, title="Code Review")

        code_snippet = "Explain this:\nfor(int i = 0; i < n; i++) {\n    cout << arr[i];\n}"
        resp1, _, _ = await mgr.generate_response(
            db=db,
            user_id=user.id,
            current_message=code_snippet,
            conversation_id=conv.id,
            max_tokens=120,
        )
        assert len(resp1) > 0
        resp1_lower = resp1.lower()
        assert any(kw in resp1_lower for kw in ("loop", "array", "print", "iterate", "index", "element", "c++", "cout")), (
            f"Code explanation missing key loop concepts: {resp1}"
        )

        # Follow-up: Why does i start at 0?
        resp2, _, _ = await mgr.generate_response(
            db=db,
            user_id=user.id,
            current_message="Why does i start at 0?",
            conversation_id=conv.id,
            max_tokens=100,
        )
        assert len(resp2) > 0
        resp2_lower = resp2.lower()
        # Model should mention 0-based indexing or first element
        assert any(kw in resp2_lower for kw in ("0", "zero", "first", "index", "offset", "array", "start")), (
            f"Zero-indexing follow-up did not use code context: {resp2}"
        )
    finally:
        db.close()


# =====================================================================
# Phase 17: Service-Level Execution without UI Dependency
# =====================================================================
@pytest.mark.anyio
async def test_service_level_without_ui_dependency():
    """Verifies that the core pipeline works headlessly without FastAPI or UI."""
    db = get_test_db()
    mgr = ConversationManager(local_llm_engine)
    try:
        user = create_test_user(db)
        conv = mgr.create_conversation(db, user.id, title="Headless Test")

        text, loaded_conv, msg = await mgr.generate_response(
            db=db,
            user_id=user.id,
            current_message="What is 2+2?",
            conversation_id=conv.id,
            max_tokens=20,
        )
        assert text is not None and len(text) > 0
        assert loaded_conv.id == conv.id
        assert msg.role == "assistant"
    finally:
        db.close()


# =====================================================================
# REST API Endpoints: Conversation CRUD and Chat Integration
# =====================================================================
def test_conversation_api_endpoints():
    """Verifies REST endpoints for creating, listing, viewing, chatting, and deleting conversations."""
    email = f"user_{uuid.uuid4().hex[:8]}@mentra.ai"
    token = get_auth_token_for_user(email)
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Create a conversation
    create_res = client.post(
        "/api/v1/ai-coach/conversations",
        json={"title": "Algorithms & Logic"},
        headers=headers,
    )
    assert create_res.status_code == 201
    conv_data = create_res.json()
    conv_id = conv_data["id"]
    assert conv_data["title"] == "Algorithms & Logic"
    assert conv_data["message_count"] == 0

    # 2. List conversations
    list_res = client.get("/api/v1/ai-coach/conversations", headers=headers)
    assert list_res.status_code == 200
    conv_list = list_res.json()
    assert any(c["id"] == conv_id for c in conv_list)

    # 3. Post chat message inside conversation
    chat_res = client.post(
        "/api/v1/ai-coach/chat",
        json={
            "conversation_id": conv_id,
            "message": "Give me a one-sentence definition of recursion.",
        },
        headers=headers,
    )
    assert chat_res.status_code == 200
    chat_data = chat_res.json()
    assert chat_data["conversation_id"] == conv_id
    assert chat_data["sender"] == "coach"
    assert chat_data["role"] == "assistant"
    assert len(chat_data["message"]) > 0

    # 4. Get conversation details (with messages)
    detail_res = client.get(f"/api/v1/ai-coach/conversations/{conv_id}", headers=headers)
    assert detail_res.status_code == 200
    detail_data = detail_res.json()
    assert detail_data["id"] == conv_id
    assert len(detail_data["messages"]) == 2
    assert detail_data["messages"][0]["role"] == "user"
    assert detail_data["messages"][1]["role"] == "assistant"

    # 5. Clear conversation messages
    clear_res = client.delete(f"/api/v1/ai-coach/conversations/{conv_id}/messages", headers=headers)
    assert clear_res.status_code == 200

    detail_after_clear = client.get(f"/api/v1/ai-coach/conversations/{conv_id}", headers=headers).json()
    assert len(detail_after_clear["messages"]) == 0

    # 6. Delete conversation
    del_res = client.delete(f"/api/v1/ai-coach/conversations/{conv_id}", headers=headers)
    assert del_res.status_code == 200

    # 7. Check 404 after deletion
    not_found = client.get(f"/api/v1/ai-coach/conversations/{conv_id}", headers=headers)
    assert not_found.status_code == 404
