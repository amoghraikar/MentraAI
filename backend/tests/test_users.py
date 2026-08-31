import uuid
from datetime import timedelta
from fastapi.testclient import TestClient
from app.core.security import create_access_token
from app.main import app

client = TestClient(app)


def unique_email() -> str:
    return f"user_{uuid.uuid4().hex[:8]}@mentra.ai"


def test_get_current_user_success() -> None:
    email = unique_email()
    password = "MyPassword123!"

    # Register & login
    reg_res = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "full_name": "Me Tester"},
    )
    assert reg_res.status_code == 201
    user_id = reg_res.json()["id"]

    login_res = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]

    # Call /users/me
    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == user_id
    assert data["email"] == email.lower()
    assert data["full_name"] == "Me Tester"
    assert data["is_active"] is True


def test_get_current_user_unauthorized_missing_token() -> None:
    response = client.get("/api/v1/users/me")
    assert response.status_code == 401


def test_get_current_user_invalid_token() -> None:
    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": "Bearer invalid.jwt.token"},
    )
    assert response.status_code == 401


def test_get_current_user_expired_token() -> None:
    expired_token = create_access_token(
        subject="some-user-id",
        expires_delta=timedelta(seconds=-10),
    )
    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {expired_token}"},
    )
    assert response.status_code == 401
    assert "expired" in response.json()["detail"].lower()
