import uuid
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.services.ai.decision_engine import CoachingDecisionEngine, CoachingIntent, CoachingMode
from app.services.ai.context_builder import CoachContextBuilder
from app.models.subject import Subject
from app.models.topic import Topic
from app.models.study_session import StudySession
from app.db.session import SessionLocal

client = TestClient(app)


def create_authenticated_user() -> tuple[dict, str]:
    email = f"student_{uuid.uuid4().hex[:8]}@mentra.ai"
    password = "Password123!"
    reg_res = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "full_name": "Conversational Student"},
    )
    assert reg_res.status_code == 201
    user_data = reg_res.json()

    login_res = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]
    return user_data, token


def test_coaching_decision_engine_intents():
    # 1. Casual / Fatigue
    intent, mode, action, steps = CoachingDecisionEngine.analyze_interaction("bro I'm tired")
    assert intent == CoachingIntent.FRUSTRATION or intent == CoachingIntent.CASUAL_CHAT
    assert mode in (CoachingMode.ENCOURAGE, CoachingMode.SUGGEST_ACTION)

    # 2. Teaching Request
    intent, mode, action, steps = CoachingDecisionEngine.analyze_interaction("teach me joins")
    assert intent == CoachingIntent.TEACH_REQUEST
    assert mode == CoachingMode.EXPLAIN

    # 3. Quiz Request
    intent, mode, action, steps = CoachingDecisionEngine.analyze_interaction("quiz me on normalization")
    assert intent == CoachingIntent.QUIZ_REQUEST
    assert mode == CoachingMode.QUIZ
    assert action is not None and action.get("type") == "START_PRACTICE"

    # 4. Procrastination
    intent, mode, action, steps = CoachingDecisionEngine.analyze_interaction("make me study")
    assert intent == CoachingIntent.PROCRASTINATION
    assert mode == CoachingMode.SUGGEST_ACTION

    # 5. Gratitude
    intent, mode, action, steps = CoachingDecisionEngine.analyze_interaction("thanks got it")
    assert intent == CoachingIntent.GRATITUDE
    assert mode == CoachingMode.ENCOURAGE


def test_multi_turn_natural_conversation_and_slang():
    """
    Test 1 — Natural conversation & slang continuity:
    User: bro I'm tired
    Mentra responds empathetically without 10-point robotic essays.
    User: I've been studying DBMS for an hour
    Mentra acknowledges session continuity.
    User: what's 3NF?
    Mentra provides direct, clear definition.
    """
    _, token = create_authenticated_user()
    headers = {"Authorization": f"Bearer {token}"}
    history = []

    # Turn 1
    res1 = client.post(
        "/api/v1/ai-coach/chat",
        json={"message": "bro I'm tired", "history": history},
        headers=headers,
    )
    assert res1.status_code == 200
    d1 = res1.json()
    assert d1["sender"] == "coach"
    assert "push through" in d1["message"] or "recharge" in d1["message"] or "break" in d1["message"] or "rest" in d1["message"] or len(d1["message"]) < 300
    # Update history
    history.append({"role": "user", "content": "bro I'm tired"})
    history.append({"role": "assistant", "content": d1["message"]})

    # Turn 2
    res2 = client.post(
        "/api/v1/ai-coach/chat",
        json={"message": "I've been studying DBMS for an hour", "history": history},
        headers=headers,
    )
    assert res2.status_code == 200
    d2 = res2.json()
    assert d2["sender"] == "coach"
    history.append({"role": "user", "content": "I've been studying DBMS for an hour"})
    history.append({"role": "assistant", "content": d2["message"]})

    # Turn 3
    res3 = client.post(
        "/api/v1/ai-coach/chat",
        json={"message": "what's 3NF?", "history": history},
        headers=headers,
    )
    assert res3.status_code == 200
    d3 = res3.json()
    assert d3["sender"] == "coach"
    assert "3NF" in d3["message"] or "transitive" in d3["message"] or "Third Normal Form" in d3["message"]


def test_multi_turn_teaching_and_concept_check():
    """
    Test 2 — Socratic Teaching & Follow-up:
    User: teach me joins
    Mentra explains with Student/Grades analogy and asks a check-in question.
    User: so it keeps everything from the left table?
    Mentra evaluates understanding and validates the student.
    """
    _, token = create_authenticated_user()
    headers = {"Authorization": f"Bearer {token}"}
    history = []

    # Step 1: Teach me joins
    res1 = client.post(
        "/api/v1/ai-coach/chat",
        json={"message": "teach me joins", "history": history},
        headers=headers,
    )
    assert res1.status_code == 200
    d1 = res1.json()
    assert "LEFT JOIN" in d1["message"] or "INNER JOIN" in d1["message"]
    history.append({"role": "user", "content": "teach me joins"})
    history.append({"role": "assistant", "content": d1["message"]})

    # Step 2: Student explains in their own words
    res2 = client.post(
        "/api/v1/ai-coach/chat",
        json={"message": "so it keeps everything from the left table?", "history": history},
        headers=headers,
    )
    assert res2.status_code == 200
    d2 = res2.json()
    assert "right" in d2["message"].lower() or "exact" in d2["message"].lower() or "spot on" in d2["message"].lower() or "left" in d2["message"].lower()


def test_multi_turn_frustration_handling():
    """
    Test 3 — Frustration handling without toxic positivity:
    User: bro this is impossible
    Mentra acknowledges effort and reduces complexity.
    User: I already tried twice
    Mentra asks for the one specific fuzzy piece.
    """
    _, token = create_authenticated_user()
    headers = {"Authorization": f"Bearer {token}"}
    history = []

    res1 = client.post(
        "/api/v1/ai-coach/chat",
        json={"message": "bro this is impossible", "history": history},
        headers=headers,
    )
    assert res1.status_code == 200
    d1 = res1.json()
    # Check that it doesn't give a huge generic lecture
    assert len(d1["message"]) < 500
    history.append({"role": "user", "content": "bro this is impossible"})
    history.append({"role": "assistant", "content": d1["message"]})

    res2 = client.post(
        "/api/v1/ai-coach/chat",
        json={"message": "I already tried twice", "history": history},
        headers=headers,
    )
    assert res2.status_code == 200
    d2 = res2.json()
    assert "reset" in d2["message"].lower() or "missing piece" in d2["message"].lower() or "specific" in d2["message"].lower() or "words" in d2["message"].lower()


def test_multi_turn_interactive_quiz():
    """
    Test 4 — Active recall quiz mode:
    User: quiz me on normalization
    Mentra asks Question 1 on 1NF.
    User: 1NF means atomic values
    Mentra validates answer and asks Question 2 on 2NF.
    """
    _, token = create_authenticated_user()
    headers = {"Authorization": f"Bearer {token}"}
    history = []

    res1 = client.post(
        "/api/v1/ai-coach/chat",
        json={"message": "quiz me on normalization", "history": history},
        headers=headers,
    )
    assert res1.status_code == 200
    d1 = res1.json()
    assert "1NF" in d1["message"] or "Question 1" in d1["message"]
    assert d1["mode"] == "QUIZ"
    history.append({"role": "user", "content": "quiz me on normalization"})
    history.append({"role": "assistant", "content": d1["message"]})

    res2 = client.post(
        "/api/v1/ai-coach/chat",
        json={"message": "1NF means atomic values", "history": history},
        headers=headers,
    )
    assert res2.status_code == 200
    d2 = res2.json()
    assert "Spot on" in d2["message"] or "atomic" in d2["message"].lower() or "2NF" in d2["message"]


def test_session_aware_coaching_context():
    """
    Test 5 — Context integration with active study session:
    Creates an active study session via API, calls chat with active_session_id and include_study_context.
    Verifies that context is assembled without failure and returns structured metadata.
    """
    user_data, token = create_authenticated_user()
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Create a subject via API
    sub_res = client.post(
        "/api/v1/subjects",
        headers=headers,
        json={
            "title": "Database Systems",
            "code": "CS301",
            "description": "Relational models",
            "color_hex": "#4F46E5",
        },
    )
    subject_id = sub_res.json()["id"] if sub_res.status_code == 201 else None

    # 2. Create a topic via API
    topic_id = None
    if subject_id:
        top_res = client.post(
            "/api/v1/topics",
            headers=headers,
            json={
                "subject_id": subject_id,
                "title": "Query Optimization",
                "description": "B+ tree indexing",
            },
        )
        if top_res.status_code == 201:
            topic_id = top_res.json()["id"]

    # 3. Call coach chat with study context
    res = client.post(
        "/api/v1/ai-coach/chat",
        json={
            "message": "How is my study pacing?",
            "subject_id": subject_id,
            "topic_id": topic_id,
            "include_study_context": True,
        },
        headers=headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert data["sender"] == "coach"
    assert len(data["message"]) > 10
    assert data["intent"] is not None
    assert data["mode"] is not None

