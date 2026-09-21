import uuid
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def create_authenticated_user() -> tuple[dict, str]:
    email = f"user_{uuid.uuid4().hex[:8]}@mentra.ai"
    password = "Mentra#Study42"
    reg_res = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "full_name": "Test User"},
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


def test_notes_goals_and_study_sessions():
    _, token1 = create_authenticated_user()
    _, token2 = create_authenticated_user()
    headers1 = {"Authorization": f"Bearer {token1}"}
    headers2 = {"Authorization": f"Bearer {token2}"}

    # Setup subject for User 1
    sub_res = client.post(
        "/api/v1/subjects",
        headers=headers1,
        json={
            "title": "Software Engineering",
            "code": "CS-201",
            "description": "System Design & Architecture",
            "color_hex": "#10B981",
        },
    )
    assert sub_res.status_code == 201
    subject_id = sub_res.json()["id"]

    # --- NOTES TESTS ---
    # 1. Create note
    note_res = client.post(
        "/api/v1/notes",
        headers=headers1,
        json={
            "subject_id": subject_id,
            "title": "Clean Code Principles",
            "content": "SOLID principles and design patterns.",
            "tags": ["Design", "Architecture"],
        },
    )
    assert note_res.status_code == 201
    note = note_res.json()
    note_id = note["id"]
    assert note["title"] == "Clean Code Principles"

    # 2. User 2 cannot access User 1's note
    assert client.get(f"/api/v1/notes/{note_id}", headers=headers2).status_code == 404

    # 3. Update note
    upd_note = client.put(
        f"/api/v1/notes/{note_id}",
        headers=headers1,
        json={"title": "Updated Clean Code Notes"},
    )
    assert upd_note.status_code == 200
    assert upd_note.json()["title"] == "Updated Clean Code Notes"

    # --- GOALS & MILESTONES TESTS ---
    # 1. Create goal with milestones
    now_iso = datetime.now(timezone.utc).isoformat()
    goal_res = client.post(
        "/api/v1/goals",
        headers=headers1,
        json={
            "subject_id": subject_id,
            "title": "Master Clean Architecture",
            "target_date": now_iso,
            "is_completed": False,
            "milestones": [
                {"title": "Read Chapter 1-5", "is_completed": False},
                {"title": "Implement sample repository pattern", "is_completed": False},
            ],
        },
    )
    assert goal_res.status_code == 201
    goal = goal_res.json()
    goal_id = goal["id"]
    milestones = goal["milestones"]
    assert len(milestones) == 2
    first_milestone_id = milestones[0]["id"]

    # 2. Toggle milestone completion
    toggle_res = client.post(
        f"/api/v1/goals/{goal_id}/milestones/{first_milestone_id}/toggle",
        headers=headers1,
    )
    assert toggle_res.status_code == 200
    assert toggle_res.json()["is_completed"] is True

    # 3. User 2 cannot toggle User 1's milestone
    assert (
        client.post(
            f"/api/v1/goals/{goal_id}/milestones/{first_milestone_id}/toggle",
            headers=headers2,
        ).status_code
        == 404
    )

    # --- STUDY SESSIONS TESTS ---
    # 1. Record completed study session
    sess_res = client.post(
        "/api/v1/sessions",
        headers=headers1,
        json={
            "subject_id": subject_id,
            "target_duration_minutes": 45,
            "actual_duration_minutes": 45,
            "study_mode": "Focus Mode",
            "is_focus_monitoring_enabled": True,
            "focus_score": 90,
            "distractions_count": 1,
            "reflection": "good",
            "started_at": now_iso,
            "ended_at": now_iso,
        },
    )
    assert sess_res.status_code == 201
    session_data = sess_res.json()
    assert session_data["focus_score"] == 90
    session_id = session_data["id"]

    # 2. Retrieve session list
    list_sess = client.get("/api/v1/sessions", headers=headers1)
    assert list_sess.status_code == 200
    assert len(list_sess.json()) == 1

    # 3. User 2 cannot access User 1's study session
    assert client.get(f"/api/v1/sessions/{session_id}", headers=headers2).status_code == 404
