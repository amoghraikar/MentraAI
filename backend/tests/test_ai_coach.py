import uuid
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.services.ai.providers import HeuristicAiProvider
from app.schemas.ai_coach import (
    AiCoachExplainResponse,
    AiCoachInterventionResponse,
    AiCoachSessionAnalysisResponse,
    AiCoachStudyPlanResponse,
)

client = TestClient(app)


def create_authenticated_user() -> tuple[dict, str]:
    email = f"user_{uuid.uuid4().hex[:8]}@mentra.ai"
    password = "Password123!"
    reg_res = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "full_name": "Coach Test User"},
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


@pytest.mark.anyio
async def test_ai_provider_heuristic_fallback():
    provider = HeuristicAiProvider()

    text = await provider.generate_text("How should I plan my study schedule?")
    assert "optimal cognitive window" in text

    explain = await provider.generate_structured(
        "Explain backpropagation",
        system_prompt=None,
        response_model=AiCoachExplainResponse,
    )
    assert explain.concept_name in ("Core Concept", "Analytical Modeling", "backpropagation", "Backpropagation")
    assert len(explain.key_points) >= 2

    intervention = await provider.generate_structured(
        "Student is showing drowsiness signals",
        system_prompt=None,
        response_model=AiCoachInterventionResponse,
    )
    assert intervention.should_intervene is True
    assert intervention.suggested_action == "micro_stretch"

    analysis = await provider.generate_structured(
        "Analyze completed session",
        system_prompt=None,
        response_model=AiCoachSessionAnalysisResponse,
    )
    assert analysis.focus_rating == "Strong"

    plan = await provider.generate_structured(
        "Create study plan",
        system_prompt=None,
        response_model=AiCoachStudyPlanResponse,
    )
    assert plan.total_days >= 3
    assert len(plan.daily_tasks) >= 2


def test_ai_coach_chat_endpoints():
    _, token = create_authenticated_user()
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Ask coach a question
    res = client.post(
        "/api/v1/ai-coach/chat",
        json={
            "message": "What is the best way to prepare for my Machine Learning exam?",
            "include_study_context": True,
        },
        headers=headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert data["sender"] == "coach"
    assert len(data["message"]) > 10

    # 2. Retrieve chat history
    history_res = client.get("/api/v1/ai-coach/chat", headers=headers)
    assert history_res.status_code == 200
    history = history_res.json()
    assert len(history) >= 2  # user message + coach response


def test_ai_coach_explain_concept():
    _, token = create_authenticated_user()
    headers = {"Authorization": f"Bearer {token}"}

    res = client.post(
        "/api/v1/ai-coach/explain",
        json={
            "concept_name": "Gradient Descent",
            "difficulty_level": "intermediate",
        },
        headers=headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert "summary" in data
    assert len(data["key_points"]) > 0


def test_ai_coach_intervention_endpoint():
    _, token = create_authenticated_user()
    headers = {"Authorization": f"Bearer {token}"}

    res = client.post(
        "/api/v1/ai-coach/intervention",
        json={
            "subject_title": "Physics",
            "topic_title": "Quantum Mechanics",
            "elapsed_minutes": 35,
            "distractions_count": 3,
            "trigger_reason": "repeated_distraction",
        },
        headers=headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert data["should_intervene"] is True
    assert "intervention_message" in data


def test_ai_coach_session_analysis_endpoint():
    _, token = create_authenticated_user()
    headers = {"Authorization": f"Bearer {token}"}

    res = client.post(
        "/api/v1/ai-coach/session-analysis",
        json={
            "session_id": "sess_12345",
            "subject_title": "Calculus",
            "topic_title": "Integration",
            "actual_duration_minutes": 45,
            "target_duration_minutes": 45,
            "focus_score": 92,
            "distractions_count": 1,
            "reflection": "good",
        },
        headers=headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert data["session_id"] == "sess_12345"
    assert "overall_feedback" in data
    assert len(data["what_went_well"]) > 0


def test_ai_coach_study_plan_endpoint():
    _, token = create_authenticated_user()
    headers = {"Authorization": f"Bearer {token}"}

    # First create a test subject
    sub_res = client.post(
        "/api/v1/subjects",
        json={
            "title": "Data Structures",
            "code": "CS201",
            "description": "Core CS",
            "color_hex": "#2563EB",
            "total_hours": 0.0,
            "target_hours": 30.0,
        },
        headers=headers,
    )
    assert sub_res.status_code == 201
    sub_id = sub_res.json()["id"]

    res = client.post(
        "/api/v1/ai-coach/study-plan",
        json={
            "subject_id": sub_id,
            "goal_title": "Master Binary Trees and Heaps",
            "available_daily_minutes": 45,
            "target_completion_days": 5,
        },
        headers=headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert "plan_title" in data
    assert len(data["daily_tasks"]) > 0


def test_ai_coach_insights_endpoint():
    _, token = create_authenticated_user()
    headers = {"Authorization": f"Bearer {token}"}

    res = client.get("/api/v1/ai-coach/insights", headers=headers)
    assert res.status_code == 200
    insights = res.json()
    assert isinstance(insights, list)
