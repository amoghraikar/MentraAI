"""Real Camera Quality Assessment Module.

Evaluates lighting, face visibility, face size, and landmark quality to determine
if camera conditions are usable for reliable study monitoring.
"""

from dataclasses import asdict, dataclass
from enum import Enum
from typing import Any, Dict, List, Optional
import cv2
import numpy as np


class CameraQualityStatus(str, Enum):
    GOOD = "GOOD"
    FAIR = "FAIR"
    POOR = "POOR"
    UNAVAILABLE = "UNAVAILABLE"


@dataclass
class CameraQualityResult:
    status: CameraQualityStatus
    face_visible: bool
    face_size_ratio: float  # Face bounding box area / Frame area
    brightness: float  # Mean brightness (0-255)
    landmark_quality: float  # Landmark availability / confidence (0.0 - 1.0)
    user_message: str  # Practical, helpful advice for camera alignment

    def to_dict(self) -> Dict[str, Any]:
        return {
            "status": self.status.value,
            "face_visible": self.face_visible,
            "face_size_ratio": round(self.face_size_ratio, 4),
            "brightness": round(self.brightness, 1),
            "landmark_quality": round(self.landmark_quality, 2),
            "user_message": self.user_message,
        }


class CameraQualityEvaluator:
    """Evaluates real camera frames and face detection metrics.

    Never displays generic focus messages when the actual issue is camera setup.
    """

    def __init__(
        self,
        min_face_size_ratio: float = 0.035,  # At least 3.5% of frame area
        min_brightness: float = 35.0,  # Below this is too dark
        max_brightness: float = 230.0,  # Above this is overexposed/washed out
    ) -> None:
        self.min_face_size_ratio = min_face_size_ratio
        self.min_brightness = min_brightness
        self.max_brightness = max_brightness

    def evaluate(
        self,
        frame: Optional[np.ndarray],
        face_present: bool,
        bounding_box: Optional[Dict[str, float]],
        landmarks: Optional[List[Any]],
    ) -> CameraQualityResult:
        """Assess camera frame and detector quality."""
        if frame is None or frame.size == 0:
            return CameraQualityResult(
                status=CameraQualityStatus.UNAVAILABLE,
                face_visible=False,
                face_size_ratio=0.0,
                brightness=0.0,
                landmark_quality=0.0,
                user_message="Camera feed unavailable. Check webcam permissions.",
            )

        # 1. Compute frame brightness via grayscale luminance
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY) if len(frame.shape) == 3 else frame
        brightness = float(cv2.mean(gray)[0])

        # 2. Evaluate face size relative to frame
        face_size_ratio = 0.0
        if face_present and bounding_box:
            bw = bounding_box.get("width", 0.0)
            bh = bounding_box.get("height", 0.0)
            face_size_ratio = max(0.0, bw * bh)

        # 3. Evaluate landmark availability
        landmark_quality = 0.0
        if face_present and landmarks and len(landmarks) >= 468:
            landmark_quality = 1.0
        elif face_present and landmarks and len(landmarks) > 0:
            landmark_quality = len(landmarks) / 468.0

        # 4. Diagnose specific physical issues
        if not face_present:
            if brightness < self.min_brightness:
                return CameraQualityResult(
                    status=CameraQualityStatus.POOR,
                    face_visible=False,
                    face_size_ratio=0.0,
                    brightness=brightness,
                    landmark_quality=0.0,
                    user_message="Room is too dark. Increase lighting so your face is visible.",
                )
            elif brightness > self.max_brightness:
                return CameraQualityResult(
                    status=CameraQualityStatus.POOR,
                    face_visible=False,
                    face_size_ratio=0.0,
                    brightness=brightness,
                    landmark_quality=0.0,
                    user_message="Camera is overexposed or backlit. Avoid bright lights behind you.",
                )
            else:
                return CameraQualityResult(
                    status=CameraQualityStatus.POOR,
                    face_visible=False,
                    face_size_ratio=0.0,
                    brightness=brightness,
                    landmark_quality=0.0,
                    user_message="Make sure your face is visible within the camera frame.",
                )

        # Face is present, check distance / size
        if face_size_ratio < self.min_face_size_ratio:
            return CameraQualityResult(
                status=CameraQualityStatus.POOR,
                face_visible=True,
                face_size_ratio=face_size_ratio,
                brightness=brightness,
                landmark_quality=landmark_quality,
                user_message="You are too far from the camera. Move slightly closer.",
            )

        # Check lighting conditions when face is detected
        if brightness < self.min_brightness or brightness > self.max_brightness:
            return CameraQualityResult(
                status=CameraQualityStatus.FAIR,
                face_visible=True,
                face_size_ratio=face_size_ratio,
                brightness=brightness,
                landmark_quality=landmark_quality,
                user_message="Suboptimal lighting. Adjust room lights for best tracking accuracy.",
            )

        # Check landmark stability
        if landmark_quality < 0.9:
            return CameraQualityResult(
                status=CameraQualityStatus.FAIR,
                face_visible=True,
                face_size_ratio=face_size_ratio,
                brightness=brightness,
                landmark_quality=landmark_quality,
                user_message="Facial mesh partially obscured. Keep face centered and unobstructed.",
            )

        # All quality checks passed
        return CameraQualityResult(
            status=CameraQualityStatus.GOOD,
            face_visible=True,
            face_size_ratio=face_size_ratio,
            brightness=brightness,
            landmark_quality=landmark_quality,
            user_message="Camera conditions are optimal for study monitoring.",
        )
