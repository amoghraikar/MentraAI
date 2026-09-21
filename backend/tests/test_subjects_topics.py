import uuid
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


def test_subject_and_topic_lifecycle():
    _, token1 = create_authenticated_user()
    _, token2 = create_authenticated_user()
    headers1 = {"Authorization": f"Bearer {token1}"}
    headers2 = {"Authorization": f"Bearer {token2}"}

    # 1. User 1 creates a subject
    sub_res = client.post(
        "/api/v1/subjects",
        headers=headers1,
        json={
            "title": "Data Analytics",
            "code": "DA-101",
            "description": "Introduction to data analysis",
            "color_hex": "#3B82F6",
            "total_hours": 0.0,
            "target_hours": 20.0,
        },
    )
    assert sub_res.status_code == 201
    subject = sub_res.json()
    subject_id = subject["id"]
    assert subject["title"] == "Data Analytics"

    # 2. User 1 adds topic to subject
    topic_res = client.post(
        "/api/v1/topics",
        headers=headers1,
        json={
            "subject_id": subject_id,
            "title": "Correlation and Regression",
            "description": "Linear regression basics",
            "progress": 0.5,
            "total_minutes": 60,
            "key_concepts": ["Pearson", "R-squared"],
            "notes_snippet": "Key formulas",
            "is_completed": False,
        },
    )
    assert topic_res.status_code == 201
    topic = topic_res.json()
    topic_id = topic["id"]
    assert topic["title"] == "Correlation and Regression"

    # 3. User 1 retrieves subjects (includes topic)
    list_res = client.get("/api/v1/subjects", headers=headers1)
    assert list_res.status_code == 200
    subjects_list = list_res.json()
    assert len(subjects_list) == 1
    assert len(subjects_list[0]["topics"]) == 1

    # 4. User 2 cannot access User 1's subject (Ownership Check)
    unauth_sub_res = client.get(f"/api/v1/subjects/{subject_id}", headers=headers2)
    assert unauth_sub_res.status_code == 404

    # 5. User 2 cannot access User 1's topic (Ownership Check)
    unauth_top_res = client.get(f"/api/v1/topics/{topic_id}", headers=headers2)
    assert unauth_top_res.status_code == 404

    # 6. User 2 cannot add topic to User 1's subject (Ownership Check)
    unauth_create_top = client.post(
        "/api/v1/topics",
        headers=headers2,
        json={
            "subject_id": subject_id,
            "title": "Malicious Topic",
            "description": "Should fail",
        },
    )
    assert unauth_create_top.status_code == 404

    # 7. User 1 updates topic
    upd_top = client.put(
        f"/api/v1/topics/{topic_id}",
        headers=headers1,
        json={"progress": 1.0, "is_completed": True},
    )
    assert upd_top.status_code == 200
    assert upd_top.json()["is_completed"] is True
    assert upd_top.json()["progress"] == 1.0

    # 8. User 1 updates subject
    upd_sub = client.put(
        f"/api/v1/subjects/{subject_id}",
        headers=headers1,
        json={"title": "Advanced Data Analytics"},
    )
    assert upd_sub.status_code == 200
    assert upd_sub.json()["title"] == "Advanced Data Analytics"

    # 9. User 1 deletes topic
    del_top = client.delete(f"/api/v1/topics/{topic_id}", headers=headers1)
    assert del_top.status_code == 204

    # 10. User 1 deletes subject
    del_sub = client.delete(f"/api/v1/subjects/{subject_id}", headers=headers1)
    assert del_sub.status_code == 204
