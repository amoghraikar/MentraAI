"""Real Face Detection & Landmark Extraction Module using MediaPipe FaceMesh."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple
import cv2
import mediapipe as mp
import numpy as np


@dataclass
class FaceLandmark:
    x: float  # Normalized 0.0 to 1.0
    y: float  # Normalized 0.0 to 1.0
    z: float


@dataclass
class FaceResult:
    present: bool
    confidence: float
    bounding_box: Optional[Dict[str, float]] = None  # {x, y, width, height} normalized
    landmarks: List[FaceLandmark] = field(default_factory=list)
    key_points: List[Tuple[float, float]] = field(default_factory=list)  # [left_eye, right_eye, nose, mouth]


class FaceDetector:
    """Production-grade on-device face detector using MediaPipe FaceMesh.

    Processes real camera frames with zero cloud dependencies.
    """

    def __init__(
        self,
        min_detection_confidence: float = 0.5,
        min_tracking_confidence: float = 0.5,
    ) -> None:
        self.mp_face_mesh = mp.solutions.face_mesh
        self.detector = self.mp_face_mesh.FaceMesh(
            static_image_mode=False,
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=min_detection_confidence,
            min_tracking_confidence=min_tracking_confidence,
        )

    def process(self, frame: np.ndarray) -> FaceResult:
        """Process a BGR video frame and return real face and landmark detections."""
        if frame is None or frame.size == 0:
            return FaceResult(present=False, confidence=0.0)

        h, w = frame.shape[:2]
        # MediaPipe requires RGB
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        rgb_frame.flags.writeable = False
        results = self.detector.process(rgb_frame)

        if not results.multi_face_landmarks:
            return FaceResult(present=False, confidence=0.0)

        face_landmarks = results.multi_face_landmarks[0]
        pts = face_landmarks.landmark

        all_x = [p.x for p in pts]
        all_y = [p.y for p in pts]

        min_x = max(0.0, min(all_x))
        max_x = min(1.0, max(all_x))
        min_y = max(0.0, min(all_y))
        max_y = min(1.0, max(all_y))

        bbox = {
            "x": float(min_x),
            "y": float(min_y),
            "width": float(max(0.01, max_x - min_x)),
            "height": float(max(0.01, max_y - min_y)),
        }

        # 4 representative anchor landmarks: left eye (33), right eye (263), nose tip (1), mouth center (13)
        left_eye = (float(pts[33].x), float(pts[33].y))
        right_eye = (float(pts[263].x), float(pts[263].y))
        nose = (float(pts[1].x), float(pts[1].y))
        mouth = (float(pts[13].x), float(pts[13].y))

        landmarks_list = [FaceLandmark(x=float(p.x), y=float(p.y), z=float(p.z)) for p in pts]

        return FaceResult(
            present=True,
            confidence=0.95,
            bounding_box=bbox,
            landmarks=landmarks_list,
            key_points=[left_eye, right_eye, nose, mouth],
        )

    def close(self) -> None:
        """Release MediaPipe resources."""
        self.detector.close()
