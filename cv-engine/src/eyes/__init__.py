"""Real Eye State Detection and Eye Aspect Ratio (EAR) Module with Personal Baseline Support."""

from dataclasses import dataclass
from enum import Enum
from typing import List, Optional, Tuple
import numpy as np


class EyeState(str, Enum):
    NORMAL_OPEN = "NORMAL_OPEN"
    EYES_CLOSED = "EYES_CLOSED"
    UNKNOWN = "UNKNOWN"


@dataclass
class EyeResult:
    left_open: bool
    right_open: bool
    left_ear: float
    right_ear: float
    ear: float  # Average EAR
    is_closed: bool
    eye_state: EyeState = EyeState.UNKNOWN
    threshold_used: float = 0.20


class EyeDetector:
    """Computes genuine Eye Aspect Ratio (EAR) using 3D facial mesh landmarks

    and supports personalized thresholding based on session calibration.
    Uses the Soukupova-Cech EAR formula:
    EAR = (|p2 - p6| + |p3 - p5|) / (2 * |p1 - p4|)
    """

    LEFT_EYE_INDICES = [33, 160, 158, 133, 153, 144]
    RIGHT_EYE_INDICES = [362, 385, 387, 263, 373, 380]

    def __init__(
        self,
        default_ear_threshold: float = 0.20,
        ear_closed_threshold: Optional[float] = None,
    ) -> None:
        self.default_ear_threshold = (
            ear_closed_threshold if ear_closed_threshold is not None else default_ear_threshold
        )

    @staticmethod
    def _compute_single_eye_ear(
        landmarks: List[Tuple[float, float, float]],
        indices: List[int],
        img_w: int,
        img_h: int,
    ) -> float:
        """Compute EAR for 6 eye landmark points in pixel coordinates."""
        pts = []
        for idx in indices:
            lm = landmarks[idx]
            pts.append(np.array([lm[0] * img_w, lm[1] * img_h]))

        p1, p2, p3, p4, p5, p6 = pts

        # Vertical distances
        v1 = np.linalg.norm(p2 - p6)
        v2 = np.linalg.norm(p3 - p5)
        # Horizontal distance
        h = np.linalg.norm(p1 - p4)

        if h < 1e-6:
            return 0.0

        ear = (v1 + v2) / (2.0 * h)
        return float(ear)

    def process(
        self,
        landmarks: Optional[List],
        img_w: int = 640,
        img_h: int = 480,
        baseline_ear: Optional[float] = None,
    ) -> EyeResult:
        """Calculate real EAR and eye open/closed state against personalized baseline."""
        if not landmarks or len(landmarks) < 468:
            return EyeResult(
                left_open=False,
                right_open=False,
                left_ear=0.0,
                right_ear=0.0,
                ear=0.0,
                is_closed=True,
                eye_state=EyeState.UNKNOWN,
                threshold_used=self.default_ear_threshold,
            )

        # Dynamic threshold based on user's calibrated resting EAR
        if baseline_ear is not None and baseline_ear > 0.15:
            # 68% of resting open EAR is an empirically robust threshold for closure
            threshold = max(0.15, min(0.25, round(baseline_ear * 0.68, 3)))
        else:
            threshold = self.default_ear_threshold

        pts = [(p.x, p.y, p.z) for p in landmarks]

        left_ear = self._compute_single_eye_ear(pts, self.LEFT_EYE_INDICES, img_w, img_h)
        right_ear = self._compute_single_eye_ear(pts, self.RIGHT_EYE_INDICES, img_w, img_h)

        avg_ear = (left_ear + right_ear) / 2.0

        left_open = left_ear >= threshold
        right_open = right_ear >= threshold
        is_closed = avg_ear < threshold
        eye_state = EyeState.EYES_CLOSED if is_closed else EyeState.NORMAL_OPEN

        return EyeResult(
            left_open=left_open,
            right_open=right_open,
            left_ear=round(left_ear, 4),
            right_ear=round(right_ear, 4),
            ear=round(avg_ear, 4),
            is_closed=is_closed,
            eye_state=eye_state,
            threshold_used=threshold,
        )
