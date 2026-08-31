import uuid
from datetime import timedelta
import pytest
from fastapi.testclient import TestClient
from app.core.security import create_access_token
from app.main import app

client = TestClient(app)


def unique_email() -> str:
    return f"user_{uuid.uuid4().hex[:8]}@mentra.ai"


def test_registration_success() -> None:
    email = unique_email()
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "SecurePassword123!",
            "full_name": "Mentra Student",
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == email.lower()
    assert data["full_name"] == "Mentra Student"
    assert data["is_active"] is True
    assert "id" in data
    assert "password" not in data
    assert "hashed_password" not in data


def test_registration_duplicate_email() -> None:
    email = unique_email()
    # First registration
    res1 = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "Password123!",
            "full_name": "First Register",
        },
    )
    assert res1.status_code == 201

    # Second registration with same email
    res2 = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "Password456!",
            "full_name": "Duplicate Register",
        },
    )
    assert res2.status_code == 409
    assert "already exists" in res2.json()["detail"]


def test_registration_invalid_email() -> None:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "not-an-email",
            "password": "Password123!",
        },
    )
    assert response.status_code == 422


def test_registration_short_password() -> None:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": unique_email(),
            "password": "123",
        },
    )
    assert response.status_code == 422


def test_login_success() -> None:
    email = unique_email()
    password = "StrongPassword123!"

    # Register
    reg_res = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": password,
            "full_name": "Login Tester",
        },
    )
    assert reg_res.status_code == 201

    # Login
    login_res = client.post(
        "/api/v1/auth/login",
        json={
            "email": email,
            "password": password,
        },
    )
    assert login_res.status_code == 200
    data = login_res.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["email"] == email.lower()


def test_login_invalid_password() -> None:
    email = unique_email()
    client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "CorrectPassword123!",
        },
    )

    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": email,
            "password": "WrongPassword!",
        },
    )
    assert response.status_code == 401
    assert "Invalid email or password" in response.json()["detail"]


def test_login_unknown_user() -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "nonexistent@mentra.ai",
            "password": "SomePassword123!",
        },
    )
    assert response.status_code == 401
    assert "Invalid email or password" in response.json()["detail"]
