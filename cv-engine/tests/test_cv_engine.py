"""Comprehensive Unit Tests for Mentra Computer Vision & Focus Engine."""

import time
from unittest.mock import MagicMock
import numpy as np
import pytest

from src import (
    CvEngine,
    DrowsinessTracker,
    EyeDetector,
    FocusBehaviorEngine,
    FocusState,
    FpsTracker,
    FrameDecoder,
    HeadPoseEstimator,
    PhoneDetector,
)


class DummyLandmark:
    def __init__(self, x: float, y: float, z: float = 0.0) -> None:
        self.x = x
        self.y = y
        self.z = z


def test_frame_decoder_raw_and_base64() -> None:
    # Test valid 10x10 synthetic image encoded to JPEG
    import cv2
    img = np.zeros((10, 10, 3), dtype=np.uint8)
    _, buffer = cv2.imencode(".jpg", img)
    raw_bytes = buffer.tobytes()

    decoded = FrameDecoder.decode_bytes(raw_bytes)
    assert decoded is not None
    assert decoded.shape == (10, 10, 3)

    # Test Base64 decoding
    import base64
    b64_str = "data:image/jpeg;base64," + base64.b64encode(raw_bytes).decode("utf-8")
    decoded_b64 = FrameDecoder.decode_base64(b64_str)
    assert decoded_b64 is not None
    assert decoded_b64.shape == (10, 10, 3)

    # Invalid input
    assert FrameDecoder.decode_bytes(b"") is None
    assert FrameDecoder.decode_base64("") is None


def test_eye_detector_ear_calculation() -> None:
    detector = EyeDetector(ear_closed_threshold=0.20)

    # Create synthetic 468 landmarks
    landmarks = [DummyLandmark(0.5, 0.5) for _ in range(478)]

    # Left eye indices: [33, 160, 158, 133, 153, 144]
    # Simulate open eye: p1(0.3, 0.5), p4(0.4, 0.5) -> width 0.1
    # Vertical: p2(0.33, 0.48), p6(0.33, 0.52) -> height 0.04; p3(0.37, 0.48), p5(0.37, 0.52) -> height 0.04
    # EAR = (0.04 + 0.04) / (2 * 0.1) = 0.40 (OPEN)
    landmarks[33] = DummyLandmark(0.30, 0.50)
    landmarks[160] = DummyLandmark(0.33, 0.48)
    landmarks[158] = DummyLandmark(0.37, 0.48)
    landmarks[133] = DummyLandmark(0.40, 0.50)
    landmarks[153] = DummyLandmark(0.37, 0.52)
    landmarks[144] = DummyLandmark(0.33, 0.52)

    # Right eye open
    landmarks[362] = DummyLandmark(0.60, 0.50)
    landmarks[385] = DummyLandmark(0.63, 0.48)
    landmarks[387] = DummyLandmark(0.67, 0.48)
    landmarks[263] = DummyLandmark(0.70, 0.50)
    landmarks[373] = DummyLandmark(0.67, 0.52)
    landmarks[380] = DummyLandmark(0.63, 0.52)

    res = detector.process(landmarks, img_w=640, img_h=480)
    assert not res.is_closed
    assert res.left_open
    assert res.right_open
    assert res.ear >= 0.25

    # Now simulate closed eyes: vertical height vanishes (0.005)
    landmarks[160] = DummyLandmark(0.33, 0.50)
    landmarks[158] = DummyLandmark(0.37, 0.50)
    landmarks[153] = DummyLandmark(0.37, 0.501)
    landmarks[144] = DummyLandmark(0.33, 0.501)

    landmarks[385] = DummyLandmark(0.63, 0.50)
    landmarks[387] = DummyLandmark(0.67, 0.50)
    landmarks[373] = DummyLandmark(0.67, 0.501)
    landmarks[380] = DummyLandmark(0.63, 0.501)

    res_closed = detector.process(landmarks, img_w=640, img_h=480)
    assert res_closed.is_closed
    assert res_closed.ear < 0.15


def test_drowsiness_tracker_blink_vs_sustained_closure() -> None:
    tracker = DrowsinessTracker(drowsiness_threshold_seconds=1.5, blink_max_duration_seconds=0.4)

    t0 = 1000.0
    # 1. Normal blink: closed for 0.2s then open
    tracker.process(eyes_closed=True, timestamp=t0)
    tracker.process(eyes_closed=True, timestamp=t0 + 0.1)
    res_open = tracker.process(eyes_closed=False, timestamp=t0 + 0.2)

    assert not res_open.is_drowsy
    assert res_open.blink_count == 1

    # 2. Sustained closure: closed for > 1.5s
    t1 = 1010.0
    tracker.process(eyes_closed=True, timestamp=t1)
    tracker.process(eyes_closed=True, timestamp=t1 + 0.5)
    tracker.process(eyes_closed=True, timestamp=t1 + 1.0)
    res_drowsy = tracker.process(eyes_closed=True, timestamp=t1 + 1.6)

    assert res_drowsy.is_drowsy
    assert res_drowsy.closed_duration_seconds >= 1.5

    # Reopening clears drowsiness
    res_recovered = tracker.process(eyes_closed=False, timestamp=t1 + 2.0)
    assert not res_recovered.is_drowsy


def test_head_pose_estimator_orientation() -> None:
    estimator = HeadPoseEstimator(yaw_threshold=18.0, pitch_down_threshold=15.0)

    # Empty/missing landmarks
    res_empty = estimator.process(None)
    assert res_empty.orientation == "UNKNOWN"

    landmarks = [DummyLandmark(0.5, 0.5) for _ in range(478)]
    # Indices: [1 (nose), 152 (chin), 33 (left eye), 263 (right eye), 61 (left mouth), 291 (right mouth)]
    landmarks[1] = DummyLandmark(0.5, 0.45)
    landmarks[152] = DummyLandmark(0.5, 0.70)
    landmarks[33] = DummyLandmark(0.35, 0.35)
    landmarks[263] = DummyLandmark(0.65, 0.35)
    landmarks[61] = DummyLandmark(0.40, 0.58)
    landmarks[291] = DummyLandmark(0.60, 0.58)

    res = estimator.process(landmarks, img_w=640, img_h=480)
    assert res.orientation in ["NORMAL_FORWARD", "LOOKING_AWAY", "LOOKING_DOWN", "LOOKING_UP"]
    assert isinstance(res.yaw, float)
    assert isinstance(res.pitch, float)


def test_phone_detector_initialization() -> None:
    detector = PhoneDetector()
    assert detector.available is True
    # Test on blank frame
    blank = np.zeros((100, 100, 3), dtype=np.uint8)
    res = detector.process(blank)
    assert res.detected is False
    assert res.confidence == 0.0


def test_focus_behavior_engine_and_scoring() -> None:
    engine = FocusBehaviorEngine(
        face_absent_threshold_seconds=2.0,
        looking_away_threshold_seconds=1.0,
        phone_threshold_seconds=1.0,
        alert_cooldown_seconds=5.0,
    )

    t0 = 100.0
    # 1. Start normal focused
    obs1 = engine.update(face_present=True, is_drowsy=False, orientation="NORMAL_FORWARD", phone_detected=False, timestamp=t0)
    assert obs1.focus_state == FocusState.FOCUSED
    assert obs1.active_alert is None

    # Tick 5 seconds of focused study
    obs2 = engine.update(face_present=True, is_drowsy=False, orientation="NORMAL_FORWARD", phone_detected=False, timestamp=t0 + 5.0)
    assert obs2.session_metrics.focused_seconds >= 5.0
    assert obs2.session_metrics.focus_score == 100

    # 2. Face absent for 1 second (under 2s threshold) -> not alerted yet
    obs3 = engine.update(face_present=False, is_drowsy=False, orientation="UNKNOWN", phone_detected=False, timestamp=t0 + 6.0)
    assert obs3.active_alert is None

    # Face absent for 2.5s (from 6.0 to 8.5) -> triggers FACE_NOT_DETECTED alert
    obs4 = engine.update(face_present=False, is_drowsy=False, orientation="UNKNOWN", phone_detected=False, timestamp=t0 + 8.5)
    assert obs4.focus_state == FocusState.FACE_NOT_DETECTED
    assert obs4.active_alert is not None
    assert obs4.active_alert.type == "FACE_NOT_DETECTED"

    # User returns -> transitions through RECOVERING to FOCUSED
    obs5 = engine.update(face_present=True, is_drowsy=False, orientation="NORMAL_FORWARD", phone_detected=False, timestamp=t0 + 9.0)
    assert obs5.focus_state == FocusState.RECOVERING
    obs5b = engine.update(face_present=True, is_drowsy=False, orientation="NORMAL_FORWARD", phone_detected=False, timestamp=t0 + 9.6)
    assert obs5b.focus_state == FocusState.FOCUSED

    # 3. Phone detected for > 1s -> triggers PHONE_DETECTED alert
    engine.update(face_present=True, is_drowsy=False, orientation="NORMAL_FORWARD", phone_detected=True, timestamp=t0 + 10.0)
    obs_phone = engine.update(face_present=True, is_drowsy=False, orientation="NORMAL_FORWARD", phone_detected=True, timestamp=t0 + 11.2)
    assert obs_phone.focus_state == FocusState.PHONE_DETECTED
    assert obs_phone.active_alert is not None
    assert obs_phone.active_alert.type == "PHONE_DETECTED"

    # Focus score calculation check: focused time / total observed time
    metrics = obs_phone.session_metrics
    assert metrics.total_observed_seconds > 0
    assert 0 <= metrics.focus_score <= 100


def test_cv_engine_master_blank_frame() -> None:
    engine = CvEngine(enable_phone_detection=False)
    blank = np.zeros((120, 160, 3), dtype=np.uint8)

    res = engine.process_frame(blank, timestamp=1000.0)
    assert res.face_detected is False
    assert res.ear == 0.0
    assert res.latency_ms >= 0.0
    assert "focus_score" in res.session_metrics
    engine.close()
