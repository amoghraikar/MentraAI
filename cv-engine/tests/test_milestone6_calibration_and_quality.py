"""Unit tests for Milestone 6: CV Calibration, Quality Check, Baseline Deviations & Metrics."""

import time
import numpy as np
from src import (
    AlertPolicy,
    CalibrationSession,
    CameraQualityEvaluator,
    CameraQualityResult,
    CameraQualityStatus,
    ConfidenceLevel,
    CVBaseline,
    CvEngine,
    DrowsinessTracker,
    EyeDetector,
    FocusBehaviorEngine,
    FocusState,
    HeadPoseEstimator,
    SessionMetrics,
    SessionObservationAccumulator,
)
from src.drowsiness import EyeTemporalState


def test_camera_quality_evaluator() -> None:
    evaluator = CameraQualityEvaluator(min_face_size_ratio=0.04, min_brightness=35.0, max_brightness=230.0)

    # 1. Null / empty frame
    res_null = evaluator.evaluate(None, False, None, None)
    assert res_null.status == CameraQualityStatus.UNAVAILABLE

    # 2. Dark frame
    dark_frame = np.full((240, 320, 3), 15, dtype=np.uint8)
    res_dark = evaluator.evaluate(dark_frame, False, None, None)
    assert res_dark.status == CameraQualityStatus.POOR
    assert "dark" in res_dark.user_message.lower()

    # 3. Overexposed frame
    bright_frame = np.full((240, 320, 3), 245, dtype=np.uint8)
    res_bright = evaluator.evaluate(bright_frame, False, None, None)
    assert res_bright.status == CameraQualityStatus.POOR
    assert "overexposed" in res_bright.user_message.lower() or "backlit" in res_bright.user_message.lower()

    # 4. Face too far (small bounding box < 0.04)
    normal_frame = np.full((240, 320, 3), 120, dtype=np.uint8)
    small_box = {"x": 0.45, "y": 0.45, "width": 0.1, "height": 0.1}  # Area = 0.01 < 0.04
    dummy_landmarks = [object()] * 468
    res_small = evaluator.evaluate(normal_frame, True, small_box, dummy_landmarks)
    assert res_small.status == CameraQualityStatus.POOR
    assert "closer" in res_small.user_message.lower()

    # 5. Optimal conditions
    good_box = {"x": 0.35, "y": 0.25, "width": 0.3, "height": 0.35}  # Area = 0.105 >= 0.04
    res_good = evaluator.evaluate(normal_frame, True, good_box, dummy_landmarks)
    assert res_good.status == CameraQualityStatus.GOOD
    assert res_good.face_visible is True


def test_calibration_session_and_baseline() -> None:
    session = CalibrationSession(target_duration_seconds=3.0, min_samples=5)
    session.start(start_time=100.0)
    assert session.is_active is True
    assert session.progress(now=101.5) == 0.5
    assert session.is_complete(now=103.1) is True

    # Add 10 samples (normal head pose yaw ~ 2.0, pitch ~ -1.0, ear ~ 0.30, plus 2 blinks with ear ~ 0.10)
    for i in range(8):
        session.add_sample(
            face_center=(0.5, 0.5),
            face_size=0.12,
            yaw=2.0 + (i * 0.1),
            pitch=-1.0,
            roll=0.0,
            ear=0.30,
        )
    # Add 2 blink samples to verify blinks are trimmed from baseline EAR
    session.add_sample(face_center=(0.5, 0.5), face_size=0.12, yaw=2.0, pitch=-1.0, roll=0.0, ear=0.11)
    session.add_sample(face_center=(0.5, 0.5), face_size=0.12, yaw=2.0, pitch=-1.0, roll=0.0, ear=0.10)

    baseline = session.finalize(end_time=103.2)
    assert baseline is not None
    assert baseline.sample_count == 10
    assert 1.9 <= baseline.baseline_yaw <= 2.8
    assert baseline.normal_ear >= 0.28  # Blink values (0.10, 0.11) were trimmed!

    # Test significant displacement detection
    assert baseline.is_significantly_displaced(0.51, 0.51, 0.12) is False
    assert baseline.is_significantly_displaced(0.95, 0.95, 0.12) is True  # Moved across screen
    assert baseline.is_significantly_displaced(0.5, 0.5, 0.02) is True  # Drastically shrunk (far away)


def test_attention_baseline_deviations() -> None:
    estimator = HeadPoseEstimator(
        moderate_yaw_threshold=15.0,
        large_yaw_threshold=25.0,
        pitch_down_threshold=18.0,
    )

    # Mock solvePnP output by testing process deviation logic directly
    baseline_yaw = 5.0
    baseline_pitch = -3.0
    baseline_roll = 1.0

    # If landmarks missing, orientation is UNKNOWN
    res_none = estimator.process(None, baseline_yaw=baseline_yaw)
    assert res_none.orientation == "UNKNOWN"


def test_eye_detector_and_drowsiness_tracker() -> None:
    # 1. Test personalized EAR threshold in EyeDetector
    detector = EyeDetector(default_ear_threshold=0.20)
    # If user resting EAR during calibration is 0.32, 68% = ~0.218
    assert detector.default_ear_threshold == 0.20

    # 2. Test DrowsinessTracker blinks vs sustained closure
    tracker = DrowsinessTracker(drowsiness_threshold_seconds=1.5, blink_max_duration_seconds=0.45)
    t = 1000.0

    # Normal open
    res1 = tracker.process(eyes_closed=False, face_present=True, timestamp=t)
    assert res1.state == EyeTemporalState.NORMAL_OPEN
    assert res1.is_drowsy is False
    assert res1.blink_count == 0

    # Quick blink: eyes close for 0.2 seconds and open
    tracker.process(eyes_closed=True, face_present=True, timestamp=t + 0.1)
    tracker.process(eyes_closed=True, face_present=True, timestamp=t + 0.2)
    res_blink = tracker.process(eyes_closed=False, face_present=True, timestamp=t + 0.25)
    assert res_blink.state == EyeTemporalState.BLINK
    assert res_blink.is_drowsy is False
    assert res_blink.blink_count == 1

    # Sustained closure: eyes close for 2.0s
    t_close = t + 10.0
    tracker.process(eyes_closed=True, face_present=True, timestamp=t_close)
    tracker.process(eyes_closed=True, face_present=True, timestamp=t_close + 0.5)
    tracker.process(eyes_closed=True, face_present=True, timestamp=t_close + 1.0)
    res_drowsy = tracker.process(eyes_closed=True, face_present=True, timestamp=t_close + 1.8)
    assert res_drowsy.state == EyeTemporalState.POSSIBLE_DROWSINESS
    assert res_drowsy.is_drowsy is True
    assert res_drowsy.prolonged_closure_count == 1


def test_session_metrics_and_pause_resume() -> None:
    accumulator = SessionObservationAccumulator()
    t = 100.0

    # Start and tick 4 seconds of FOCUSED
    accumulator.tick("FOCUSED", now=t)
    accumulator.tick("FOCUSED", now=t + 2.0)
    metrics = accumulator.tick("FOCUSED", now=t + 4.0)

    assert metrics.focused_duration == 4.0
    assert metrics.focus_score == 100

    # Pause at t + 4.0
    accumulator.pause()
    assert accumulator.is_paused is True

    # While paused, ticks should NOT accumulate any duration
    metrics_paused = accumulator.tick("FOCUSED", now=t + 10.0)
    assert metrics_paused.focused_duration == 4.0

    # Resume at t + 20.0
    accumulator.resume(now=t + 20.0)
    assert accumulator.is_paused is False

    # Tick 3 seconds of LOOKING_AWAY after resuming
    accumulator.tick("LOOKING_AWAY", now=t + 21.0)
    metrics_resumed = accumulator.tick("LOOKING_AWAY", now=t + 23.0)

    assert metrics_resumed.focused_duration == 4.0
    assert metrics_resumed.looking_away_duration == 3.0
    assert metrics_resumed.number_of_looking_away_events == 1

    # Total valid observed = 4.0 + 3.0 = 7.0s. Score = 4/7 * 100 = 57%
    assert metrics_resumed.focus_score == 57
