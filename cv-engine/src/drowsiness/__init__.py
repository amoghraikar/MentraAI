"""Real Drowsiness & Blink Tracking Module using Temporal Eye Closure Analysis."""

from dataclasses import dataclass
import time
from typing import Optional


@dataclass
class DrowsinessResult:
    is_drowsy: bool
    closed_duration_seconds: float
    blink_count: int


class DrowsinessTracker:
    """Tracks eye closure over time to distinguish normal blinks from prolonged drowsiness."""

    def __init__(
        self,
        drowsiness_threshold_seconds: float = 1.5,
        blink_max_duration_seconds: float = 0.45,
    ) -> None:
        self.drowsiness_threshold_seconds = drowsiness_threshold_seconds
        self.blink_max_duration_seconds = blink_max_duration_seconds

        self._closure_start_time: Optional[float] = None
        self._is_drowsy: bool = False
        self._blink_count: int = 0
        self._consecutive_closed_frames: int = 0

    def process(self, eyes_closed: bool, timestamp: Optional[float] = None) -> DrowsinessResult:
        """Process eye closure state at the given timestamp (or current time)."""
        now = timestamp if timestamp is not None else time.time()

        if eyes_closed:
            self._consecutive_closed_frames += 1
            if self._closure_start_time is None:
                self._closure_start_time = now

            duration = now - self._closure_start_time
            if duration >= self.drowsiness_threshold_seconds and self._consecutive_closed_frames >= 3:
                self._is_drowsy = True

            return DrowsinessResult(
                is_drowsy=self._is_drowsy,
                closed_duration_seconds=round(duration, 2),
                blink_count=self._blink_count,
            )
        else:
            # Eyes just opened
            if self._closure_start_time is not None:
                duration = now - self._closure_start_time
                if duration <= self.blink_max_duration_seconds and self._consecutive_closed_frames >= 1:
                    self._blink_count += 1

            self._closure_start_time = None
            self._consecutive_closed_frames = 0
            self._is_drowsy = False

            return DrowsinessResult(
                is_drowsy=False,
                closed_duration_seconds=0.0,
                blink_count=self._blink_count,
            )

    def reset(self) -> None:
        """Reset temporal drowsiness state."""
        self._closure_start_time = None
        self._is_drowsy = False
        self._blink_count = 0
        self._consecutive_closed_frames = 0
