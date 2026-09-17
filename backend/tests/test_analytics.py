import uuid
from datetime import datetime, timedelta, timezone
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def create_authenticated_user() -> tuple[dict, str]:
    email = f"user_{uuid.uuid4().hex[:8]}@mentra.ai"
    password = "Password123!"
    reg_res = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "full_name": "Analytics User"},
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


def test_empty_analytics_overview():
    _, token = create_authenticated_user()
    headers = {"Authorization": f"Bearer {token}"}

    res = client.get("/api/v1/analytics/overview?range=7d", headers=headers)
    assert res.status_code == 200
    data = res.json()

    assert data["time_range"] == "7d"
    assert data["total_study_minutes"] == 0
    assert data["total_sessions_count"] == 0
    assert data["average_focus_score"] == 0
    assert len(data["daily_trends"]) == 7
    # All daily trend minutes should be 0
    for day in data["daily_trends"]:
        assert day["study_minutes"] == 0
        assert day["focus_score"] == 0

    assert len(data["ai_insights"]) >= 1
    assert data["goal_summary"]["active_goals"] == 0


def test_analytics_with_sessions_and_subjects():
    _, token = create_authenticated_user()
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Create Subject
    sub_res = client.post(
        "/api/v1/subjects",
        headers=headers,
        json={
            "title": "Machine Learning",
            "code": "CS-401",
            "description": "Neural Networks",
            "color_hex": "#10B981",
        },
    )
    assert sub_res.status_code == 201
    subject_id = sub_res.json()["id"]

    # 2. Create Topic
    top_res = client.post(
        "/api/v1/topics",
        headers=headers,
        json={
            "subject_id": subject_id,
            "title": "Transformers & Attention",
            "target_hours": 10.0,
        },
    )
    assert top_res.status_code == 201
    topic_id = top_res.json()["id"]

    # 3. Create Goal
    now = datetime.now(timezone.utc)
    goal_res = client.post(
        "/api/v1/goals",
        headers=headers,
        json={
            "subject_id": subject_id,
            "title": "Complete Transformer Paper",
            "target_date": (now + timedelta(days=5)).isoformat(),
            "milestones": [
                {"title": "Read Vaswani et al."},
                {"title": "Implement Multihead Attention"},
            ],
        },
    )
    assert goal_res.status_code == 201

    # 4. Record Study Sessions
    # Session 1: Today, 45 mins, 92 focus, 2 distractions
    s1_res = client.post(
        "/api/v1/sessions",
        headers=headers,
        json={
            "subject_id": subject_id,
            "topic_id": topic_id,
            "target_duration_minutes": 45,
            "actual_duration_minutes": 45,
            "study_mode": "Focus Mode",
            "is_focus_monitoring_enabled": True,
            "focus_score": 92,
            "distractions_count": 2,
            "reflection": "good",
            "started_at": (now - timedelta(minutes=50)).isoformat(),
            "ended_at": (now - timedelta(minutes=5)).isoformat(),
        },
    )
    assert s1_res.status_code == 201

    # Session 2: Yesterday, 30 mins, 86 focus, 1 distraction
    yesterday = now - timedelta(days=1)
    s2_res = client.post(
        "/api/v1/sessions",
        headers=headers,
        json={
            "subject_id": subject_id,
            "topic_id": topic_id,
            "target_duration_minutes": 30,
            "actual_duration_minutes": 30,
            "study_mode": "Focus Mode",
            "is_focus_monitoring_enabled": True,
            "focus_score": 86,
            "distractions_count": 1,
            "reflection": "good",
            "started_at": (yesterday - timedelta(minutes=35)).isoformat(),
            "ended_at": (yesterday - timedelta(minutes=5)).isoformat(),
        },
    )
    assert s2_res.status_code == 201

    # 5. Query 7d Analytics Overview
    res = client.get("/api/v1/analytics/overview?range=7d", headers=headers)
    assert res.status_code == 200
    data = res.json()

    assert data["total_study_minutes"] == 75
    assert data["total_sessions_count"] == 2
    assert data["completed_sessions_count"] == 2
    assert data["average_session_duration_minutes"] == 37
    assert data["average_focus_score"] == 89
    assert data["total_distractions_count"] == 3

    # Subject distribution check
    assert len(data["subject_distribution"]) == 1
    assert data["subject_distribution"][0]["subject_title"] == "Machine Learning"
    assert data["subject_distribution"][0]["total_minutes"] == 75
    assert data["subject_distribution"][0]["percentage"] == 100

    # Goal check
    assert data["goal_summary"]["active_goals"] == 1

    # Streak check
    assert data["streak_summary"]["total_study_days"] >= 2
    assert data["streak_summary"]["current_streak_days"] >= 2

    # AI Insights
    assert len(data["ai_insights"]) >= 1
    assert "Focus" in data["ai_insights"][0]["category"] or "Streak" in data["ai_insights"][0]["title"]


def test_analytics_user_isolation():
    _, token1 = create_authenticated_user()
    _, token2 = create_authenticated_user()
    headers1 = {"Authorization": f"Bearer {token1}"}
    headers2 = {"Authorization": f"Bearer {token2}"}

    # User 1 creates subject and session
    sub_res = client.post(
        "/api/v1/subjects",
        headers=headers1,
        json={"title": "Private Subject User 1", "code": "U1", "description": "Desc", "color_hex": "#10B981"},
    )
    sub1_id = sub_res.json()["id"]

    now = datetime.now(timezone.utc)
    client.post(
        "/api/v1/sessions",
        headers=headers1,
        json={
            "subject_id": sub1_id,
            "target_duration_minutes": 60,
            "actual_duration_minutes": 60,
            "study_mode": "Focus Mode",
            "is_focus_monitoring_enabled": True,
            "focus_score": 95,
            "distractions_count": 0,
            "reflection": "good",
            "started_at": (now - timedelta(minutes=65)).isoformat(),
            "ended_at": (now - timedelta(minutes=5)).isoformat(),
        },
    )

    # User 2 queries analytics: should have 0 minutes, not User 1's data
    res2 = client.get("/api/v1/analytics/overview?range=7d", headers=headers2)
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["total_study_minutes"] == 0
    assert data2["total_sessions_count"] == 0
    assert len(data2["subject_distribution"]) == 0
