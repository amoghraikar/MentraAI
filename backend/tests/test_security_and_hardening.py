import uuid
from datetime import datetime, timedelta, timezone
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def create_user_and_token(name: str = "Test Student") -> tuple[dict, str]:
    email = f"user_{uuid.uuid4().hex[:8]}@mentra.ai"
    reg_res = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "StrongPassword123!",
            "full_name": name,
        },
    )
    assert reg_res.status_code == 201
    user_data = reg_res.json()

    login_res = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "StrongPassword123!"},
    )
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]
    return user_data, token


def test_idor_subject_isolation():
    # User A creates a subject
    user_a, token_a = create_user_and_token("Alice")
    user_b, token_b = create_user_and_token("Bob")

    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}

    sub_res = client.post(
        "/api/v1/subjects",
        headers=headers_a,
        json={
            "title": "Alice Private Subject",
            "code": "ALICE-101",
            "description": "Confidential",
            "color_hex": "#4F46E5",
        },
    )
    assert sub_res.status_code == 201
    subject_id = sub_res.json()["id"]

    # Bob tries to read Alice's subject by ID
    get_res = client.get(f"/api/v1/subjects/{subject_id}", headers=headers_b)
    assert get_res.status_code == 404

    # Bob tries to update Alice's subject
    put_res = client.put(
        f"/api/v1/subjects/{subject_id}",
        headers=headers_b,
        json={"title": "Hacked Title"},
    )
    assert put_res.status_code == 404

    # Bob tries to delete Alice's subject
    del_res = client.delete(f"/api/v1/subjects/{subject_id}", headers=headers_b)
    assert del_res.status_code == 404

    # Verify Alice's subject still exists and unchanged
    verify_res = client.get(f"/api/v1/subjects/{subject_id}", headers=headers_a)
    assert verify_res.status_code == 200
    assert verify_res.json()["title"] == "Alice Private Subject"


def test_idor_topic_and_goal_cross_tenant_prevention():
    user_a, token_a = create_user_and_token("Alice")
    user_b, token_b = create_user_and_token("Bob")

    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # Alice creates subject
    sub_res = client.post(
        "/api/v1/subjects",
        headers=headers_a,
        json={"title": "Algorithms", "code": "CS-201", "color_hex": "#10B981"},
    )
    alice_sub_id = sub_res.json()["id"]

    # Bob tries to create a topic attached to Alice's subject
    top_res = client.post(
        "/api/v1/topics",
        headers=headers_b,
        json={"subject_id": alice_sub_id, "title": "Injected Topic"},
    )
    assert top_res.status_code == 404

    # Bob tries to create a goal attached to Alice's subject
    goal_res = client.post(
        "/api/v1/goals",
        headers=headers_b,
        json={
            "subject_id": alice_sub_id,
            "title": "Injected Goal",
            "target_date": (datetime.now(timezone.utc) + timedelta(days=7)).isoformat(),
        },
    )
    assert goal_res.status_code == 404


def test_idor_session_and_notes_isolation():
    user_a, token_a = create_user_and_token("Alice")
    user_b, token_b = create_user_and_token("Bob")

    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # Alice creates subject and note
    sub_res = client.post(
        "/api/v1/subjects",
        headers=headers_a,
        json={"title": "Databases", "code": "CS-301"},
    )
    alice_sub_id = sub_res.json()["id"]

    note_res = client.post(
        "/api/v1/notes",
        headers=headers_a,
        json={
            "subject_id": alice_sub_id,
            "title": "Alice Exam Notes",
            "content": "Secret exam answers",
        },
    )
    assert note_res.status_code == 201
    note_id = note_res.json()["id"]

    # Bob tries to read Alice's note
    assert client.get(f"/api/v1/notes/{note_id}", headers=headers_b).status_code == 404
    # Bob tries to delete Alice's note
    assert client.delete(f"/api/v1/notes/{note_id}", headers=headers_b).status_code == 404

    # Bob tries to record a study session referencing Alice's subject
    now = datetime.now(timezone.utc)
    sess_res = client.post(
        "/api/v1/sessions",
        headers=headers_b,
        json={
            "subject_id": alice_sub_id,
            "target_duration_minutes": 30,
            "actual_duration_minutes": 30,
            "focus_score": 90,
            "started_at": now.isoformat(),
            "ended_at": now.isoformat(),
        },
    )
    assert sess_res.status_code == 404


def test_input_validation_and_boundary_checks():
    _, token = create_user_and_token("Validator")
    headers = {"Authorization": f"Bearer {token}"}

    # 1. AI Coach Message too long (> 2000 chars)
    giant_msg = "A" * 2500
    res = client.post(
        "/api/v1/ai-coach/chat",
        headers=headers,
        json={"message": giant_msg},
    )
    assert res.status_code == 422

    # 2. Study Session invalid focus score (> 100 or < 0)
    now = datetime.now(timezone.utc)
    res_score = client.post(
        "/api/v1/sessions",
        headers=headers,
        json={
            "subject_id": "dummy_sub",
            "target_duration_minutes": 30,
            "actual_duration_minutes": 30,
            "focus_score": 150,  # Invalid
            "started_at": now.isoformat(),
            "ended_at": now.isoformat(),
        },
    )
    assert res_score.status_code == 422

    # 3. Empty Subject Title
    res_sub = client.post(
        "/api/v1/subjects",
        headers=headers,
        json={"title": "", "code": "CS-000"},
    )
    assert res_sub.status_code == 422


def test_tampered_token_rejection():
    # Attempt request with forged token signature
    tampered_headers = {"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.bogus_signature"}
    res = client.get("/api/v1/subjects", headers=tampered_headers)
    assert res.status_code == 401
