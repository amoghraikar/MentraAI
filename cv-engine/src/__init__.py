"""Mentra Computer Vision & Focus Engine Package."""

from dataclasses import asdict, dataclass
import time
from typing import Any, Dict, List, Optional, Tuple
import numpy as np

from .attention import HeadPoseEstimator, HeadPoseResult
from .behavior import FocusAlert, FocusBehaviorEngine, FocusState, SessionMetrics
from .camera import FpsTracker, FrameDecoder
from .drowsiness import DrowsinessResult, DrowsinessTracker
from .eyes import EyeDetector, EyeResult
from .face import FaceDetector, FaceResult
from .objects import PhoneDetector, PhoneResult


@dataclass
class CvFrameResult:
    timestamp: float
    face_detected: bool
    face_confidence: float
    bounding_box: Optional[Dict[str, float]]
    landmarks: List[Tuple[float, float]]  # Key 2D anchor points [left_eye, right_eye, nose, mouth]
    yaw: float
    pitch: float
    roll: float
    orientation: str
    ear: float
    left_ear: float
    right_ear: float
    eyes_closed: bool
    is_drowsy: bool
    phone_detected: bool
    phone_confidence: float
    phone_bounding_box: Optional[List[float]]
    focus_state: str
    alert: Optional[Dict[str, Any]]
    session_metrics: Dict[str, Any]
    fps: float
    latency_ms: float
    phone_available: bool = False

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


class CvEngine:
    """Master on-device Computer Vision Engine for Mentra."""

    def __init__(self, enable_phone_detection: bool = True) -> None:
        self.face_detector = FaceDetector()
        self.eye_detector = EyeDetector()
        self.head_pose_estimator = HeadPoseEstimator()
        self.drowsiness_tracker = DrowsinessTracker()
        self.phone_detector = PhoneDetector() if enable_phone_detection else None
        self.behavior_engine = FocusBehaviorEngine()
        self.fps_tracker = FpsTracker()

    def process_frame(
        self,
        frame: np.ndarray,
        timestamp: Optional[float] = None,
    ) -> CvFrameResult:
        """Process a single BGR camera frame through all real CV detectors."""
        start_time = time.time()
        now = timestamp if timestamp is not None else start_time

        if frame is None or frame.size == 0:
            return self._build_empty_result(now)

        h, w = frame.shape[:2]

        # 1. Face Detection & 3D Mesh
        face_res = self.face_detector.process(frame)

        # 2. Eye Analysis & Head Pose
        if face_res.present and face_res.landmarks:
            eye_res = self.eye_detector.process(face_res.landmarks, img_w=w, img_h=h)
            drowsy_res = self.drowsiness_tracker.process(eye_res.is_closed, timestamp=now)
            pose_res = self.head_pose_estimator.process(face_res.landmarks, img_w=w, img_h=h)
        else:
            eye_res = EyeResult(
                left_open=False,
                right_open=False,
                left_ear=0.0,
                right_ear=0.0,
                ear=0.0,
                is_closed=False,
            )
            drowsy_res = self.drowsiness_tracker.process(False, timestamp=now)
            pose_res = HeadPoseResult(yaw=0.0, pitch=0.0, roll=0.0, orientation="UNKNOWN")

        # 3. Phone / Object Detection
        if self.phone_detector and self.phone_detector.available:
            phone_res = self.phone_detector.process(frame)
        else:
            phone_res = PhoneResult(detected=False, confidence=0.0, available=False)

        # 4. Focus Behavior & Temporal Debouncing
        behavior_obs = self.behavior_engine.update(
            face_present=face_res.present,
            is_drowsy=drowsy_res.is_drowsy,
            orientation=pose_res.orientation,
            phone_detected=phone_res.detected,
            timestamp=now,
        )

        # 5. Measure Latency & FPS
        fps = self.fps_tracker.tick()
        latency_ms = round((time.time() - start_time) * 1000.0, 1)

        alert_dict = asdict(behavior_obs.active_alert) if behavior_obs.active_alert else None
        metrics_dict = asdict(behavior_obs.session_metrics) if behavior_obs.session_metrics else {}

        return CvFrameResult(
            timestamp=now,
            face_detected=face_res.present,
            face_confidence=face_res.confidence,
            bounding_box=face_res.bounding_box,
            landmarks=face_res.key_points,
            yaw=pose_res.yaw,
            pitch=pose_res.pitch,
            roll=pose_res.roll,
            orientation=pose_res.orientation,
            ear=eye_res.ear,
            left_ear=eye_res.left_ear,
            right_ear=eye_res.right_ear,
            eyes_closed=eye_res.is_closed,
            is_drowsy=drowsy_res.is_drowsy,
            phone_detected=phone_res.detected,
            phone_confidence=phone_res.confidence,
            phone_bounding_box=phone_res.bounding_box,
            phone_available=phone_res.available,
            focus_state=behavior_obs.focus_state.value,
            alert=alert_dict,
            session_metrics=metrics_dict,
            fps=fps,
            latency_ms=latency_ms,
        )

    def _build_empty_result(self, now: float) -> CvFrameResult:
        """Fallback for invalid or black frames."""
        behavior_obs = self.behavior_engine.update(
            face_present=False,
            is_drowsy=False,
            orientation="UNKNOWN",
            phone_detected=False,
            timestamp=now,
        )
        phone_avail = self.phone_detector.available if self.phone_detector else False
        return CvFrameResult(
            timestamp=now,
            face_detected=False,
            face_confidence=0.0,
            bounding_box=None,
            landmarks=[],
            yaw=0.0,
            pitch=0.0,
            roll=0.0,
            orientation="UNKNOWN",
            ear=0.0,
            left_ear=0.0,
            right_ear=0.0,
            eyes_closed=False,
            is_drowsy=False,
            phone_detected=False,
            phone_confidence=0.0,
            phone_bounding_box=None,
            phone_available=phone_avail,
            focus_state=behavior_obs.focus_state.value,
            alert=asdict(behavior_obs.active_alert) if behavior_obs.active_alert else None,
            session_metrics=asdict(behavior_obs.session_metrics) if behavior_obs.session_metrics else {},
            fps=0.0,
            latency_ms=0.0,
        )

    def reset(self) -> None:
        """Reset session metrics and temporal states."""
        self.drowsiness_tracker.reset()
        self.behavior_engine.reset()

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
    "FocusState",
    "FocusAlert",
    "SessionMetrics",
]
