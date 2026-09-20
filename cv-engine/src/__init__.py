"""Mentra Computer Vision & Focus Engine Package."""

from dataclasses import asdict, dataclass
import time
from typing import Any, Dict, List, Optional, Tuple
import numpy as np

from .attention import HeadPoseEstimator, HeadPoseResult
from .behavior import (
    AlertPolicy,
    BehaviorObservation,
    ConfidenceLevel,
    FocusAlert,
    FocusBehaviorEngine,
    FocusState,
    SessionMetrics,
    SessionObservationAccumulator,
)
from .calibration import CalibrationSession, CVBaseline
from .camera import (
    CameraQualityEvaluator,
    CameraQualityResult,
    CameraQualityStatus,
    FpsTracker,
    FrameDecoder,
)
from .drowsiness import DrowsinessResult, DrowsinessTracker, EyeTemporalState
from .eyes import EyeDetector, EyeResult, EyeState
from .face import FaceDetector, FaceResult
from .objects import PhoneDetector, PhoneResult


@dataclass
class CvFrameResult:
    timestamp: float
    face_detected: bool
    face_confidence: float
    bounding_box: Optional[Dict[str, float]]
    landmarks: List[Tuple[float, float]]  # Key 2D anchor points
    yaw: float
    pitch: float
    roll: float
    yaw_deviation: float
    pitch_deviation: float
    roll_deviation: float
    orientation: str
    ear: float
    left_ear: float
    right_ear: float
    eyes_closed: bool
    eye_state: str
    is_drowsy: bool
    phone_detected: bool
    phone_confidence: float
    phone_bounding_box: Optional[List[float]]
    focus_state: str
    confidence_level: str
    camera_quality: Dict[str, Any]
    alert: Optional[Dict[str, Any]]
    session_metrics: Dict[str, Any]
    fps: float
    latency_ms: float
    phone_available: bool = False
    baseline_active: bool = False

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


class CvEngine:
    """Master on-device Computer Vision Engine for Mentra with Calibration & Quality Controls."""

    def __init__(self, enable_phone_detection: bool = True) -> None:
        self.face_detector = FaceDetector()
        self.eye_detector = EyeDetector()
        self.head_pose_estimator = HeadPoseEstimator()
        self.drowsiness_tracker = DrowsinessTracker()
        self.phone_detector = PhoneDetector() if enable_phone_detection else None
        self.behavior_engine = FocusBehaviorEngine()
        self.quality_evaluator = CameraQualityEvaluator()
        self.calibration_session = CalibrationSession(target_duration_seconds=3.0)
        self.fps_tracker = FpsTracker()

        self.current_baseline: Optional[CVBaseline] = None

    def start_calibration(self) -> None:
        """Begin a 3-second personal baseline calibration."""
        self.calibration_session.start()

    def process_calibration_frame(
        self,
        frame: np.ndarray,
        timestamp: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Process a frame during calibration and return real-time calibration progress."""
        now = timestamp if timestamp is not None else time.time()
        if frame is None or frame.size == 0:
            return {
                "active": self.calibration_session.is_active,
                "progress": self.calibration_session.progress(now),
                "is_complete": False,
                "face_detected": False,
                "quality": "UNAVAILABLE",
                "message": "Camera frame unavailable.",
            }

        h, w = frame.shape[:2]
        face_res = self.face_detector.process(frame)
        quality_res = self.quality_evaluator.evaluate(
            frame, face_res.present, face_res.bounding_box, face_res.landmarks
        )

        if face_res.present and face_res.landmarks:
            eye_res = self.eye_detector.process(face_res.landmarks, img_w=w, img_h=h)
            pose_res = self.head_pose_estimator.process(face_res.landmarks, img_w=w, img_h=h)

            bw = face_res.bounding_box.get("width", 0.0) if face_res.bounding_box else 0.0
            bh = face_res.bounding_box.get("height", 0.0) if face_res.bounding_box else 0.0
            bx = face_res.bounding_box.get("x", 0.5) if face_res.bounding_box else 0.5
            by = face_res.bounding_box.get("y", 0.5) if face_res.bounding_box else 0.5
            center = (bx + bw / 2.0, by + bh / 2.0)
            size = bw * bh

            self.calibration_session.add_sample(
                face_center=center,
                face_size=size,
                yaw=pose_res.yaw,
                pitch=pose_res.pitch,
                roll=pose_res.roll,
                ear=eye_res.ear,
            )

        progress = self.calibration_session.progress(now)
        is_complete = self.calibration_session.is_complete(now)

        return {
            "active": self.calibration_session.is_active,
            "progress": round(progress, 2),
            "is_complete": is_complete,
            "face_detected": face_res.present,
            "quality": quality_res.status.value,
            "message": quality_res.user_message,
        }

    def finish_calibration(self) -> Optional[CVBaseline]:
        """Finalize calibration and store current baseline."""
        baseline = self.calibration_session.finalize()
        if baseline:
            self.current_baseline = baseline
        return baseline

    def set_baseline(self, baseline: CVBaseline) -> None:
        """Set pre-existing or updated baseline."""
        self.current_baseline = baseline

    def get_baseline(self) -> Optional[CVBaseline]:
        """Return the active session baseline."""
        return self.current_baseline

    def evaluate_quality(self, frame: np.ndarray) -> CameraQualityResult:
        """Evaluate camera quality independently."""
        if frame is None or frame.size == 0:
            return self.quality_evaluator.evaluate(None, False, None, None)
        face_res = self.face_detector.process(frame)
        return self.quality_evaluator.evaluate(
            frame, face_res.present, face_res.bounding_box, face_res.landmarks
        )

    def pause(self) -> None:
        """Pause focus monitoring accumulation."""
        self.behavior_engine.pause()

    def resume(self) -> None:
        """Resume focus monitoring accumulation."""
        self.behavior_engine.resume()

    @property
    def is_paused(self) -> bool:
        return self.behavior_engine.is_paused

    def process_frame(
        self,
        frame: np.ndarray,
        timestamp: Optional[float] = None,
    ) -> CvFrameResult:
        """Process a single BGR camera frame through all real CV detectors with baseline correction."""
        start_time = time.time()
        now = timestamp if timestamp is not None else start_time

        if frame is None or frame.size == 0:
            return self._build_empty_result(now)

        h, w = frame.shape[:2]

        # 1. Face Detection & 3D Mesh
        face_res = self.face_detector.process(frame)

        # 2. Camera Quality Check
        quality_res = self.quality_evaluator.evaluate(
            frame, face_res.present, face_res.bounding_box, face_res.landmarks
        )

        # 3. Eye Analysis & Head Pose (with personalized baselines)
        baseline_ear = self.current_baseline.normal_ear if self.current_baseline else None
        baseline_yaw = self.current_baseline.baseline_yaw if self.current_baseline else 0.0
        baseline_pitch = self.current_baseline.baseline_pitch if self.current_baseline else 0.0
        baseline_roll = self.current_baseline.baseline_roll if self.current_baseline else 0.0

        if face_res.present and face_res.landmarks:
            eye_res = self.eye_detector.process(
                face_res.landmarks, img_w=w, img_h=h, baseline_ear=baseline_ear
            )
            drowsy_res = self.drowsiness_tracker.process(
                eye_res.is_closed, face_present=True, timestamp=now
            )
            pose_res = self.head_pose_estimator.process(
                face_res.landmarks,
                img_w=w,
                img_h=h,
                baseline_yaw=baseline_yaw,
                baseline_pitch=baseline_pitch,
                baseline_roll=baseline_roll,
            )
        else:
            eye_res = EyeResult(
                left_open=False,
                right_open=False,
                left_ear=0.0,
                right_ear=0.0,
                ear=0.0,
                is_closed=False,
                eye_state=EyeState.UNKNOWN,
            )
            drowsy_res = self.drowsiness_tracker.process(False, face_present=False, timestamp=now)
            pose_res = HeadPoseResult(
                yaw=0.0,
                pitch=0.0,
                roll=0.0,
                yaw_deviation=0.0,
                pitch_deviation=0.0,
                roll_deviation=0.0,
                orientation="UNKNOWN",
            )

        # 4. Phone / Object Detection
        if self.phone_detector and self.phone_detector.available:
            phone_res = self.phone_detector.process(frame)
        else:
            phone_res = PhoneResult(detected=False, confidence=0.0, available=False)

        # 5. Temporal Behavior State Machine & Central Alert Policy
        behavior_obs = self.behavior_engine.update(
            face_present=face_res.present,
            is_drowsy=drowsy_res.is_drowsy,
            orientation=pose_res.orientation,
            phone_detected=phone_res.detected,
            face_confidence=face_res.confidence,
            camera_quality_status=quality_res.status.value,
            landmark_quality=quality_res.landmark_quality,
            eye_state=drowsy_res.state.value,
            timestamp=now,
        )

        # 6. Performance & Diagnostic Telemetry
        fps = self.fps_tracker.tick()
        latency_ms = round((time.time() - start_time) * 1000.0, 1)

        alert_dict = asdict(behavior_obs.active_alert) if behavior_obs.active_alert else None
        metrics_dict = behavior_obs.session_metrics.to_dict() if behavior_obs.session_metrics else {}

        return CvFrameResult(
            timestamp=now,
            face_detected=face_res.present,
            face_confidence=face_res.confidence,
            bounding_box=face_res.bounding_box,
            landmarks=face_res.key_points,
            yaw=pose_res.yaw,
            pitch=pose_res.pitch,
            roll=pose_res.roll,
            yaw_deviation=pose_res.yaw_deviation,
            pitch_deviation=pose_res.pitch_deviation,
            roll_deviation=pose_res.roll_deviation,
            orientation=pose_res.orientation,
            ear=eye_res.ear,
            left_ear=eye_res.left_ear,
            right_ear=eye_res.right_ear,
            eyes_closed=eye_res.is_closed,
            eye_state=drowsy_res.state.value,
            is_drowsy=drowsy_res.is_drowsy,
            phone_detected=phone_res.detected,
            phone_confidence=phone_res.confidence,
            phone_bounding_box=phone_res.bounding_box,
            phone_available=phone_res.available,
            focus_state=behavior_obs.focus_state.value,
            confidence_level=behavior_obs.confidence_level.value,
            camera_quality=quality_res.to_dict(),
            alert=alert_dict,
            session_metrics=metrics_dict,
            fps=fps,
            latency_ms=latency_ms,
            baseline_active=self.current_baseline is not None,
        )

    def _build_empty_result(self, now: float) -> CvFrameResult:
        """Fallback for invalid or black frames."""
        behavior_obs = self.behavior_engine.update(
            face_present=False,
            is_drowsy=False,
            orientation="UNKNOWN",
            phone_detected=False,
            face_confidence=0.0,
            camera_quality_status=CameraQualityStatus.UNAVAILABLE.value,
            landmark_quality=0.0,
            eye_state=EyeTemporalState.UNKNOWN.value,
            timestamp=now,
        )
        phone_avail = self.phone_detector.available if self.phone_detector else False
        empty_quality = CameraQualityResult(
            status=CameraQualityStatus.UNAVAILABLE,
            face_visible=False,
            face_size_ratio=0.0,
            brightness=0.0,
            landmark_quality=0.0,
            user_message="Camera feed unavailable.",
        )
        return CvFrameResult(
            timestamp=now,
            face_detected=False,
            face_confidence=0.0,
            bounding_box=None,
            landmarks=[],
            yaw=0.0,
            pitch=0.0,
            roll=0.0,
            yaw_deviation=0.0,
            pitch_deviation=0.0,
            roll_deviation=0.0,
            orientation="UNKNOWN",
            ear=0.0,
            left_ear=0.0,
            right_ear=0.0,
            eyes_closed=False,
            eye_state=EyeTemporalState.UNKNOWN.value,
            is_drowsy=False,
            phone_detected=False,
            phone_confidence=0.0,
            phone_bounding_box=None,
            phone_available=phone_avail,
            focus_state=behavior_obs.focus_state.value,
            confidence_level=behavior_obs.confidence_level.value,
            camera_quality=empty_quality.to_dict(),
            alert=asdict(behavior_obs.active_alert) if behavior_obs.active_alert else None,
            session_metrics=behavior_obs.session_metrics.to_dict() if behavior_obs.session_metrics else {},
            fps=0.0,
            latency_ms=0.0,
            baseline_active=self.current_baseline is not None,
        )

    def reset(self) -> None:
        """Reset session metrics, temporal state machines, and calibration."""
        self.drowsiness_tracker.reset()
        self.behavior_engine.reset()
        self.calibration_session.reset()

    def close(self) -> None:
        """Release underlying detector resources."""
        self.face_detector.close()


__all__ = [
    "CvEngine",
    "CvFrameResult",
    "FaceDetector",
    "EyeDetector",
    "HeadPoseEstimator",
    "DrowsinessTracker",
    "PhoneDetector",
    "FocusBehaviorEngine",
    "FrameDecoder",
    "FpsTracker",
    "CameraQualityEvaluator",
    "CameraQualityResult",
    "CameraQualityStatus",
    "CalibrationSession",
    "CVBaseline",
    "FocusState",
    "ConfidenceLevel",
    "FocusAlert",
    "SessionMetrics",
]
