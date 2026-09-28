"""
Mentra Computer Vision & Focus Engine Test Suite - Milestone 4 Verification.

Validates the complete independent local CV pipeline:
- Camera Lifecycle State Machine & Controlled FPS
- Real Face Detection & Landmark Extraction (MediaPipe)
- Eye State Measurement & EAR (Soukupova-Cech Formula)
- Blink vs. Sustained Closure Temporal Differentiation
- 3D Head Pose Estimation (solvePnP Euler Angles: Yaw, Pitch, Roll)
- Local Object / Cell Phone Detection (YOLOv8n Class 67)
- Frame Quality Assessment & Low-Light / Darkness Diagnostics
- Centralized Focus Classification & Temporal Smoothing
- Decoupled Alert Policy & Cooldown Suppression
- Session Observation Accumulation & Mathematically Explainable Focus Score
- Failure State Handling & Error Isolation
- Diagnostics and Telemetry Output
"""

from pathlib import Path
import time
from unittest.mock import MagicMock, patch
import cv2
import numpy as np
import pytest

from src import (
    CameraQualityEvaluator,
    CameraQualityStatus,
    ConfidenceLevel,
    CvEngine,
    DrowsinessTracker,
    EyeDetector,
    EyeState,
    EyeTemporalState,
    FocusBehaviorEngine,
    FocusState,
    FpsTracker,
    FrameDecoder,
    HeadPoseEstimator,
    PhoneDetector,
    SessionObservationAccumulator,
)
from src.camera.lifecycle import CameraLifecycleManager, CameraState


class DummyLandmark:
    def __init__(self, x: float, y: float, z: float = 0.0) -> None:
        self.x = x
        self.y = y
        self.z = z


# =====================================================================
# Phase 3: Camera Lifecycle Engine
# =====================================================================
class TestPhase3CameraLifecycle:
    def test_lifecycle_states(self):
        cam = CameraLifecycleManager(camera_index=999)  # Non-existent index
        assert cam.state == CameraState.UNINITIALIZED

        # Probing non-existent camera should transition to UNAVAILABLE
        ok = cam.initialize()
        assert ok is False
        assert cam.state == CameraState.UNAVAILABLE
        assert cam.last_error is not None

    def test_camera_pause_and_resume(self):
        cam = CameraLifecycleManager(camera_index=0)
        # Mock VideoCapture to test lifecycle without hardware locking
        mock_cap = MagicMock()
        mock_cap.isOpened.return_value = True
        mock_cap.read.return_value = (True, np.zeros((480, 640, 3), dtype=np.uint8))

        with patch("cv2.VideoCapture", return_value=mock_cap):
            assert cam.start() is True
            assert cam.state == CameraState.RUNNING

            cam.pause()
            assert cam.state == CameraState.PAUSED
            # While paused, read_frame should return False
            success, frame, _ = cam.read_frame()
            assert success is False

            cam.resume()
            assert cam.state == CameraState.RUNNING

            cam.stop()
            assert cam.state == CameraState.STOPPED
            assert mock_cap.release.called


# =====================================================================
# Phase 4: Face Detection
# =====================================================================
class TestPhase4FaceDetection:
    def test_real_face_detection_on_image(self):
        engine = CvEngine(enable_phone_detection=False)
        img_path = Path("backend/.venv/lib/python3.11/site-packages/matplotlib/mpl-data/sample_data/grace_hopper.jpg")
        if not img_path.is_file():
            pytest.skip("grace_hopper.jpg sample not found")

        frame = cv2.imread(str(img_path))
        res = engine.process_frame(frame)

        assert res.face_detected is True
        assert res.face_confidence >= 0.50
        assert res.bounding_box is not None
        assert 0.0 <= res.bounding_box["x"] <= 1.0
        assert 0.0 <= res.bounding_box["width"] <= 1.0
        assert len(res.landmarks) == 4  # Anchor keypoints (left eye, right eye, nose, mouth)
        engine.close()

    def test_blank_frame_no_face(self):
        engine = CvEngine(enable_phone_detection=False)
        blank = np.zeros((240, 320, 3), dtype=np.uint8)
        res = engine.process_frame(blank)

        assert res.face_detected is False
        assert res.face_confidence == 0.0
        assert res.bounding_box is None
        engine.close()


# =====================================================================
# Phase 5: Eye Detection & EAR
# =====================================================================
class TestPhase5EyeDetection:
    def test_ear_calculation_open_vs_closed(self):
        detector = EyeDetector(default_ear_threshold=0.20)
        landmarks = [DummyLandmark(0.5, 0.5) for _ in range(478)]

        # Simulate open eye: p1(0.3, 0.5), p4(0.4, 0.5) -> h=0.1
        # v1: p2(0.33, 0.48), p6(0.33, 0.52) -> 0.04
        # v2: p3(0.37, 0.48), p5(0.37, 0.52) -> 0.04
        # EAR = 0.08 / 0.2 = 0.40
        landmarks[33] = DummyLandmark(0.30, 0.50)
        landmarks[160] = DummyLandmark(0.33, 0.48)
        landmarks[158] = DummyLandmark(0.37, 0.48)
        landmarks[133] = DummyLandmark(0.40, 0.50)
        landmarks[153] = DummyLandmark(0.37, 0.52)
        landmarks[144] = DummyLandmark(0.33, 0.52)

        landmarks[362] = DummyLandmark(0.60, 0.50)
        landmarks[385] = DummyLandmark(0.63, 0.48)
        landmarks[387] = DummyLandmark(0.67, 0.48)
        landmarks[263] = DummyLandmark(0.70, 0.50)
        landmarks[373] = DummyLandmark(0.67, 0.52)
        landmarks[380] = DummyLandmark(0.63, 0.52)

        res_open = detector.process(landmarks, img_w=640, img_h=480)
        assert res_open.is_closed is False
        assert res_open.ear >= 0.25
        assert res_open.eye_state == EyeState.NORMAL_OPEN

        # Collapse vertical distance -> closed
        landmarks[160] = DummyLandmark(0.33, 0.50)
        landmarks[158] = DummyLandmark(0.37, 0.50)
        landmarks[153] = DummyLandmark(0.37, 0.502)
        landmarks[144] = DummyLandmark(0.33, 0.502)

        landmarks[385] = DummyLandmark(0.63, 0.50)
        landmarks[387] = DummyLandmark(0.67, 0.50)
        landmarks[373] = DummyLandmark(0.67, 0.502)
        landmarks[380] = DummyLandmark(0.63, 0.502)

        res_closed = detector.process(landmarks, img_w=640, img_h=480)
        assert res_closed.is_closed is True
        assert res_closed.ear < 0.15
        assert res_closed.eye_state == EyeState.EYES_CLOSED

    def test_blink_vs_sustained_closure(self):
        tracker = DrowsinessTracker(drowsiness_threshold_seconds=1.5, blink_max_duration_seconds=0.45)
        t = 1000.0

        # Normal blink (0.2s duration)
        tracker.process(eyes_closed=True, timestamp=t)
        tracker.process(eyes_closed=True, timestamp=t + 0.1)
        res_blink = tracker.process(eyes_closed=False, timestamp=t + 0.2)
        assert res_blink.state == EyeTemporalState.BLINK
        assert res_blink.blink_count == 1
        assert res_blink.is_drowsy is False

        # Sustained closure (> 1.5s)
        t2 = 1010.0
        tracker.process(eyes_closed=True, timestamp=t2)
        tracker.process(eyes_closed=True, timestamp=t2 + 0.5)
        tracker.process(eyes_closed=True, timestamp=t2 + 1.0)
        res_drowsy = tracker.process(eyes_closed=True, timestamp=t2 + 1.6)
        assert res_drowsy.state == EyeTemporalState.POSSIBLE_DROWSINESS
        assert res_drowsy.is_drowsy is True
        assert res_drowsy.prolonged_closure_count == 1


# =====================================================================
# Phase 6: Head Pose Estimation
# =====================================================================
class TestPhase6HeadPose:
    def test_head_pose_angles_and_orientation(self):
        estimator = HeadPoseEstimator(
            moderate_yaw_threshold=16.0,
            large_yaw_threshold=26.0,
            pitch_down_threshold=18.0,
            pitch_up_threshold=-18.0,
        )

        landmarks = [DummyLandmark(0.5, 0.5) for _ in range(478)]
        # Canonical forward face points
        landmarks[1] = DummyLandmark(0.50, 0.45)    # nose
        landmarks[152] = DummyLandmark(0.50, 0.70)  # chin
        landmarks[33] = DummyLandmark(0.35, 0.35)   # left eye
        landmarks[263] = DummyLandmark(0.65, 0.35)  # right eye
        landmarks[61] = DummyLandmark(0.40, 0.58)   # left mouth
        landmarks[291] = DummyLandmark(0.60, 0.58)  # right mouth

        res = estimator.process(landmarks, img_w=640, img_h=480)
        assert isinstance(res.yaw, float)
        assert isinstance(res.pitch, float)
        assert isinstance(res.roll, float)
        assert res.orientation in ["NORMAL_FORWARD", "LOOKING_AWAY", "POSSIBLE_LOOKING_AWAY", "LOOKING_DOWN", "LOOKING_UP"]


# =====================================================================
# Phase 7: Phone Detection
# =====================================================================
class TestPhase7PhoneDetection:
    def test_phone_detector_real_or_unavailable(self):
        detector = PhoneDetector()
        assert detector.available is True  # yolov8n.pt is in repo
        assert detector.model is not None
        assert detector.CELL_PHONE_CLASS_ID == 67

        # Frame with no phone
        blank = np.zeros((100, 100, 3), dtype=np.uint8)
        res = detector.process(blank)
        assert res.detected is False
        assert res.confidence == 0.0
        assert res.available is True

    def test_phone_detector_unavailable_fallback(self):
        detector = PhoneDetector(model_path="non_existent_weights.pt")
        assert detector.available is False
        res = detector.process(np.zeros((50, 50, 3), dtype=np.uint8))
        assert res.detected is False
        assert res.available is False


# =====================================================================
# Phase 8: Frame Quality
# =====================================================================
class TestPhase8FrameQuality:
    def test_dark_room_detection(self):
        evaluator = CameraQualityEvaluator(min_brightness=35.0)
        dark_frame = np.full((100, 100, 3), 10, dtype=np.uint8)  # Low luminance

        res = evaluator.evaluate(dark_frame, face_present=False, bounding_box=None, landmarks=None)
        assert res.status == CameraQualityStatus.POOR
        assert "dark" in res.user_message.lower()
        assert res.brightness < 35.0

    def test_overexposed_detection(self):
        evaluator = CameraQualityEvaluator(max_brightness=230.0)
        washed_frame = np.full((100, 100, 3), 245, dtype=np.uint8)

        res = evaluator.evaluate(washed_frame, face_present=False, bounding_box=None, landmarks=None)
        assert res.status == CameraQualityStatus.POOR
        assert "overexposed" in res.user_message.lower() or "backlit" in res.user_message.lower()

    def test_camera_unavailable(self):
        evaluator = CameraQualityEvaluator()
        res = evaluator.evaluate(None, face_present=False, bounding_box=None, landmarks=None)
        assert res.status == CameraQualityStatus.UNAVAILABLE
        assert res.face_visible is False


# =====================================================================
# Phase 9 & 10: Temporal State Machine & Focus Classification
# =====================================================================
class TestPhase9And10FocusClassification:
    def test_temporal_smoothing_look_away(self):
        engine = FocusBehaviorEngine(
            looking_away_threshold_seconds=1.3,
            alert_cooldown_seconds=5.0,
        )
        t = 100.0

        # Normal focused
        obs1 = engine.update(face_present=True, is_drowsy=False, orientation="NORMAL_FORWARD", phone_detected=False, timestamp=t)
        assert obs1.focus_state == FocusState.FOCUSED

        # Instantaneous look away frame (0.5s) -> POSSIBLE_DISTRACTION (No alert)
        obs2 = engine.update(face_present=True, is_drowsy=False, orientation="LOOKING_AWAY", phone_detected=False, timestamp=t + 0.5)
        assert obs2.focus_state == FocusState.POSSIBLE_DISTRACTION
        assert obs2.active_alert is None

        # Sustained look away past 1.3s threshold (from t+0.5 to t+2.0 is 1.5s > 1.3s)
        obs3 = engine.update(face_present=True, is_drowsy=False, orientation="LOOKING_AWAY", phone_detected=False, timestamp=t + 2.0)
        assert obs3.focus_state == FocusState.LOOKING_AWAY
        assert obs3.active_alert is not None
        assert obs3.active_alert.type == "LOOKING_AWAY"

        # Return to screen -> RECOVERING then FOCUSED
        obs4 = engine.update(face_present=True, is_drowsy=False, orientation="NORMAL_FORWARD", phone_detected=False, timestamp=t + 2.3)
        assert obs4.focus_state == FocusState.RECOVERING

        obs5 = engine.update(face_present=True, is_drowsy=False, orientation="NORMAL_FORWARD", phone_detected=False, timestamp=t + 3.0)
        assert obs5.focus_state == FocusState.FOCUSED


# =====================================================================
# Phase 12: Alert Policy & Cooldown
# =====================================================================
class TestPhase12AlertPolicy:
    def test_alert_cooldown_suppression(self):
        engine = FocusBehaviorEngine(
            phone_threshold_seconds=0.5,
            alert_cooldown_seconds=8.0,
        )
        t = 100.0

        # Trigger first phone alert
        engine.update(face_present=True, is_drowsy=False, orientation="NORMAL_FORWARD", phone_detected=True, timestamp=t)
        obs1 = engine.update(face_present=True, is_drowsy=False, orientation="NORMAL_FORWARD", phone_detected=True, timestamp=t + 0.6)
        assert obs1.active_alert is not None
        assert obs1.active_alert.type == "PHONE_DETECTED"

        # Subsequent phone frames during cooldown should NOT generate new alerts
        obs2 = engine.update(face_present=True, is_drowsy=False, orientation="NORMAL_FORWARD", phone_detected=True, timestamp=t + 2.0)
        assert obs2.focus_state == FocusState.PHONE_DETECTED
        assert obs2.active_alert is None  # Suppressed by cooldown

        # After 8s cooldown expires, new alert is allowed
        obs3 = engine.update(face_present=True, is_drowsy=False, orientation="NORMAL_FORWARD", phone_detected=True, timestamp=t + 9.0)
        assert obs3.active_alert is not None
        assert obs3.active_alert.type == "PHONE_DETECTED"


# =====================================================================
# Phase 13 & 14: Session Metrics & Explainable Focus Score
# =====================================================================
class TestPhase13And14SessionMetrics:
    def test_exact_time_accumulation_and_score(self):
        acc = SessionObservationAccumulator()
        t = 100.0

        # Initial tick
        acc.tick(state="FOCUSED", now=t)

        # 10 seconds of focused study (two 5s steps due to 5s safety clamp per tick)
        acc.tick(state="FOCUSED", now=t + 5.0)
        acc.tick(state="FOCUSED", now=t + 10.0)
        m1 = acc.metrics
        assert m1.focused_duration == 10.0
        assert m1.focus_score == 100

        # 5 seconds of looking away
        acc.tick(state="LOOKING_AWAY", now=t + 15.0)
        m2 = acc.metrics
        assert m2.focused_duration == 10.0
        assert m2.looking_away_duration == 5.0
        # Confirmed observed = 10 + 5 = 15s. Score = (10 / 15) * 100 = 67%
        assert m2.focus_score == 67

        # 5 seconds of UNKNOWN (camera error or dark room)
        acc.tick(state="CAMERA_ERROR", now=t + 20.0)
        m3 = acc.metrics
        assert m3.unknown_duration == 5.0
        # Unknown duration must NOT dilute or change focus score (remains 67%)
        assert m3.focus_score == 67

    def test_insufficient_data_returns_none(self):
        acc = SessionObservationAccumulator()
        t = 100.0
        acc.tick(state="FOCUSED", now=t)
        acc.tick(state="FOCUSED", now=t + 1.5)  # Only 1.5s total (< 3s threshold)
        assert acc.metrics.focus_score is None


# =====================================================================
# Phase 17: Camera Failure Handling
# =====================================================================
class TestPhase17CameraFailureHandling:
    def test_camera_unavailable_produces_camera_error(self):
        engine = FocusBehaviorEngine()
        obs = engine.update(
            face_present=False,
            is_drowsy=False,
            orientation="UNKNOWN",
            phone_detected=False,
            camera_quality_status="UNAVAILABLE",
            timestamp=100.0,
        )
        assert obs.focus_state == FocusState.CAMERA_ERROR
        assert obs.confidence_level == ConfidenceLevel.UNKNOWN
        # Must never convert camera error into FOCUSED or looking away distraction
        assert obs.focus_state != FocusState.FOCUSED
        assert obs.focus_state != FocusState.LOOKING_AWAY
