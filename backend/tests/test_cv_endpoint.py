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
    assert "yaw_deviation" in data
    assert "camera_quality" in data
    assert data["latency_ms"] >= 0.0


def test_cv_calibration_lifecycle(client: TestClient) -> None:
    # 1. Start calibration
    resp_start = client.post("/api/v1/cv/calibrate/start")
    assert resp_start.status_code == 200
    assert resp_start.json()["status"] == "active"

    # 2. Feed blank frame
    blank = np.zeros((120, 160, 3), dtype=np.uint8)
    _, buffer = cv2.imencode(".jpg", blank)
    b64_str = "data:image/jpeg;base64," + base64.b64encode(buffer).decode("utf-8")

    resp_frame = client.post(
        "/api/v1/cv/calibrate/frame",
        json={"image_base64": b64_str, "timestamp": 100.0},
    )
    assert resp_frame.status_code == 200
    frame_data = resp_frame.json()
    assert frame_data["active"] is True
    assert "progress" in frame_data

    # 3. Quality evaluation endpoint
    resp_quality = client.post("/api/v1/cv/quality", json={"image_base64": b64_str})
    assert resp_quality.status_code == 200
    quality_data = resp_quality.json()
    assert quality_data["status"] in ("POOR", "UNAVAILABLE")
    assert "user_message" in quality_data

    # 4. Pause and Resume endpoints
    resp_pause = client.post("/api/v1/cv/pause")
    assert resp_pause.status_code == 200
    assert "paused" in resp_pause.json()["message"]

    resp_resume = client.post("/api/v1/cv/resume")
    assert resp_resume.status_code == 200
    assert "resumed" in resp_resume.json()["message"]


def test_cv_reset_endpoint(client: TestClient) -> None:
    response = client.post("/api/v1/cv/reset")
    assert response.status_code == 200
    data = response.json()
    assert "reset" in data["message"]
