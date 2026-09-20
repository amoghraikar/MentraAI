"""CV Baseline & Calibration Session Module for Mentra.

Establishes a local personal baseline (normal sitting posture, screen gaze,
resting EAR, and head angles) without storing any biometric identity information.
"""

from dataclasses import asdict, dataclass, field
import time
from typing import Any, Dict, List, Optional, Tuple
import numpy as np


@dataclass
class CVBaseline:
    """Session baseline established during the 3-second calibration phase."""

    face_center_x: float  # Normalized X coordinate (0.0 to 1.0)
    face_center_y: float  # Normalized Y coordinate (0.0 to 1.0)
    face_size: float  # Bounding box area ratio (0.0 to 1.0)
    baseline_yaw: float  # Resting head yaw in degrees
    baseline_pitch: float  # Resting head pitch in degrees
    baseline_roll: float  # Resting head roll in degrees
    normal_ear: float  # Resting Eye Aspect Ratio
    calibration_duration: float  # Duration of calibration in seconds
    sample_count: int  # Number of valid frames used
    quality: str  # "GOOD", "FAIR", "POOR"
    created_at: float  # Unix timestamp

    def to_dict(self) -> Dict[str, Any]:
        return {
            "face_center_x": round(self.face_center_x, 3),
            "face_center_y": round(self.face_center_y, 3),
            "face_size": round(self.face_size, 4),
            "baseline_yaw": round(self.baseline_yaw, 1),
            "baseline_pitch": round(self.baseline_pitch, 1),
            "baseline_roll": round(self.baseline_roll, 1),
            "normal_ear": round(self.normal_ear, 4),
            "calibration_duration": round(self.calibration_duration, 2),
            "sample_count": self.sample_count,
            "quality": self.quality,
            "created_at": self.created_at,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "CVBaseline":
        return cls(
            face_center_x=float(data.get("face_center_x", 0.5)),
            face_center_y=float(data.get("face_center_y", 0.5)),
            face_size=float(data.get("face_size", 0.1)),
            baseline_yaw=float(data.get("baseline_yaw", 0.0)),
            baseline_pitch=float(data.get("baseline_pitch", 0.0)),
            baseline_roll=float(data.get("baseline_roll", 0.0)),
            normal_ear=float(data.get("normal_ear", 0.28)),
            calibration_duration=float(data.get("calibration_duration", 3.0)),
            sample_count=int(data.get("sample_count", 30)),
            quality=str(data.get("quality", "GOOD")),
            created_at=float(data.get("created_at", time.time())),
        )

    def is_significantly_displaced(
        self,
        current_center_x: float,
        current_center_y: float,
        current_size: float,
    ) -> bool:
        """Checks if the user's posture or camera position has radically shifted.

        Used to warn user or gracefully request recalibration rather than generating false alerts.
        """
        center_dist = np.sqrt(
            (current_center_x - self.face_center_x) ** 2
            + (current_center_y - self.face_center_y) ** 2
        )
        if center_dist > 0.45:  # Significant shift across frame
            return True

        if self.face_size > 0.01:
            size_ratio = current_size / self.face_size
            if size_ratio < 0.35 or size_ratio > 2.8:  # Moved drastically closer/further
                return True

        return False


class CalibrationSession:
    """Manages the 3-second calibration phase.

    Collects real observations and filters out blinks/glitches to compute stable baselines.
    """

    def __init__(self, target_duration_seconds: float = 3.0, min_samples: int = 8) -> None:
        self.target_duration = target_duration_seconds
        self.min_samples = min_samples

        self._start_time: Optional[float] = None
        self._samples: List[Dict[str, float]] = []
        self._is_active: bool = False

    def start(self, start_time: Optional[float] = None) -> None:
        """Start a new calibration session."""
        self._start_time = start_time if start_time is not None else time.time()
        self._samples = []
        self._is_active = True

    @property
    def is_active(self) -> bool:
        return self._is_active

    def progress(self, now: Optional[float] = None) -> float:
        """Return calibration progress from 0.0 to 1.0."""
        if not self._is_active or self._start_time is None:
            return 0.0
        current = now if now is not None else time.time()
        elapsed = current - self._start_time
        return min(1.0, max(0.0, elapsed / self.target_duration))

    def is_complete(self, now: Optional[float] = None) -> bool:
        """Check if target calibration duration has elapsed."""
        if not self._is_active or self._start_time is None:
            return False
        current = now if now is not None else time.time()
        return (current - self._start_time) >= self.target_duration

    def add_sample(
        self,
        face_center: Tuple[float, float],
        face_size: float,
        yaw: float,
        pitch: float,
        roll: float,
        ear: float,
    ) -> None:
        """Add a valid detection frame sample to calibration."""
        if not self._is_active:
            return

        self._samples.append(
            {
                "cx": face_center[0],
                "cy": face_center[1],
                "size": face_size,
                "yaw": yaw,
                "pitch": pitch,
                "roll": roll,
                "ear": ear,
            }
        )

    def finalize(self, end_time: Optional[float] = None) -> Optional[CVBaseline]:
        """Aggregate samples and produce the session baseline."""
        self._is_active = False
        now = end_time if end_time is not None else time.time()
        duration = (now - self._start_time) if self._start_time else 0.0

        if len(self._samples) < self.min_samples:
            # Insufficient real samples (e.g. user wasn't in front of camera)
            return None

        # Extract measurements
        cxs = [s["cx"] for s in self._samples]
        cys = [s["cy"] for s in self._samples]
        sizes = [s["size"] for s in self._samples]
        yaws = [s["yaw"] for s in self._samples]
        pitches = [s["pitch"] for s in self._samples]
        rolls = [s["roll"] for s in self._samples]

        # For eye aspect ratio, filter out blinks (values below 0.15 or lowest 15% quantile)
        ears = sorted([s["ear"] for s in self._samples if s["ear"] > 0.12])
        if not ears:
            ears = [s["ear"] for s in self._samples]

        # Trim bottom 20% to avoid blink contamination
        trim_idx = max(0, int(len(ears) * 0.2))
        active_ears = ears[trim_idx:] if trim_idx < len(ears) else ears

        # Compute stable medians
        baseline = CVBaseline(
            face_center_x=float(np.median(cxs)),
            face_center_y=float(np.median(cys)),
            face_size=float(np.median(sizes)),
            baseline_yaw=float(np.median(yaws)),
            baseline_pitch=float(np.median(pitches)),
            baseline_roll=float(np.median(rolls)),
            normal_ear=float(np.median(active_ears)) if active_ears else 0.28,
            calibration_duration=duration,
            sample_count=len(self._samples),
            quality="GOOD" if len(self._samples) >= 15 else "FAIR",
            created_at=now,
        )
        return baseline

    def reset(self) -> None:
        """Reset the calibration accumulator."""
        self._start_time = None
        self._samples.clear()
        self._is_active = False
