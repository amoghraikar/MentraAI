"""Real Drowsiness & Blink Tracking Module using Temporal Eye Closure Analysis.

Accurately distinguishes normal blinks (<= 0.45s), brief eye closures,
and sustained possible drowsiness (>= 1.5s) without medical overclaiming.
"""

from dataclasses import dataclass
from enum import Enum
import time
from typing import Optional


class EyeTemporalState(str, Enum):
    NORMAL_OPEN = "NORMAL_OPEN"
    BLINK = "BLINK"
    EYES_CLOSED = "EYES_CLOSED"
    POSSIBLE_DROWSINESS = "POSSIBLE_DROWSINESS"
    UNKNOWN = "UNKNOWN"


@dataclass
class DrowsinessResult:
    state: EyeTemporalState
    is_drowsy: bool
    closed_duration_seconds: float
    blink_count: int
    prolonged_closure_count: int


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
        self._prolonged_closure_count: int = 0
        self._consecutive_closed_frames: int = 0

    def process(
        self,
        eyes_closed: bool,
        face_present: bool = True,
        timestamp: Optional[float] = None,
    ) -> DrowsinessResult:
        """Process eye closure state at the given timestamp."""
        now = timestamp if timestamp is not None else time.time()

        if not face_present:
            # Cannot determine eye state without face
            self._closure_start_time = None
            self._consecutive_closed_frames = 0
            self._is_drowsy = False
            return DrowsinessResult(
                state=EyeTemporalState.UNKNOWN,
                is_drowsy=False,
                closed_duration_seconds=0.0,
                blink_count=self._blink_count,
                prolonged_closure_count=self._prolonged_closure_count,
            )

        if eyes_closed:
            self._consecutive_closed_frames += 1
            if self._closure_start_time is None:
                self._closure_start_time = now

            duration = now - self._closure_start_time

            if duration >= self.drowsiness_threshold_seconds and self._consecutive_closed_frames >= 3:
                if not self._is_drowsy:
                    self._is_drowsy = True
                    self._prolonged_closure_count += 1
                state = EyeTemporalState.POSSIBLE_DROWSINESS
            elif duration > self.blink_max_duration_seconds:
                state = EyeTemporalState.EYES_CLOSED
            else:
                state = EyeTemporalState.EYES_CLOSED  # Currently closed within blink window

            return DrowsinessResult(
                state=state,
                is_drowsy=self._is_drowsy,
                closed_duration_seconds=round(duration, 2),
                blink_count=self._blink_count,
                prolonged_closure_count=self._prolonged_closure_count,
            )
        else:
            # Eyes are currently open
            reopened_from_blink = False
            if self._closure_start_time is not None:
                duration = now - self._closure_start_time
                if duration <= self.blink_max_duration_seconds and self._consecutive_closed_frames >= 1:
                    self._blink_count += 1
                    reopened_from_blink = True

            self._closure_start_time = None
            self._consecutive_closed_frames = 0
            self._is_drowsy = False

            state = EyeTemporalState.BLINK if reopened_from_blink else EyeTemporalState.NORMAL_OPEN
            return DrowsinessResult(
                state=state,
                is_drowsy=False,
                closed_duration_seconds=0.0,
                blink_count=self._blink_count,
                prolonged_closure_count=self._prolonged_closure_count,
            )

    def reset(self) -> None:
        """Reset temporal drowsiness state."""
        self._closure_start_time = None
        self._is_drowsy = False
        self._blink_count = 0
        self._prolonged_closure_count = 0
        self._consecutive_closed_frames = 0
