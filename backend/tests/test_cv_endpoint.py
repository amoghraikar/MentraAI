"""Integration tests for the Computer Vision REST endpoints."""

import base64
import cv2
from fastapi.testclient import TestClient
import numpy as np
import pytest

from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


def test_cv_status_endpoint(client: TestClient) -> None:
    response = client.get("/api/v1/cv/status")
    assert response.status_code == 200
    data = response.json()
    assert "engine_ready" in data
    assert "face_mesh_active" in data
    assert "supported_classes" in data
    assert data["status"] == "ready"


def test_cv_process_frame_blank(client: TestClient) -> None:
    # Create a blank 160x120 synthetic JPEG frame
    blank = np.zeros((120, 160, 3), dtype=np.uint8)
    _, buffer = cv2.imencode(".jpg", blank)
    b64_str = "data:image/jpeg;base64," + base64.b64encode(buffer).decode("utf-8")

    payload = {
        "image_base64": b64_str,
        "timestamp": 1000.0,
    }

    response = client.post("/api/v1/cv/process-frame", json=payload)
    assert response.status_code == 200
    data = response.json()

    assert data["face_detected"] is False
    assert data["ear"] == 0.0
    assert data["phone_detected"] is False
    assert "session_metrics" in data
    assert "focus_score" in data["session_metrics"]
    assert data["latency_ms"] >= 0.0


def test_cv_reset_endpoint(client: TestClient) -> None:
    response = client.post("/api/v1/cv/reset")
    assert response.status_code == 200
    data = response.json()
    assert "reset" in data["message"]
