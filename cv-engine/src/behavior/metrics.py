"""Real Focus Session Observation Accumulator and Deterministic Scoring.

Only records events produced by the real CV engine.
UNKNOWN time is strictly excluded from focused time and the focus score denominator.
"""

from dataclasses import asdict, dataclass
import time
from typing import Any, Dict, Optional


@dataclass
class SessionMetrics:
    """Session observation metrics accumulated over the study period."""

    total_observed_seconds: float = 0.0
    focused_duration: float = 0.0
    looking_away_duration: float = 0.0
    eyes_closed_duration: float = 0.0
    possible_drowsiness_duration: float = 0.0
    phone_detected_duration: float = 0.0
    face_not_detected_duration: float = 0.0
    unknown_duration: float = 0.0

    number_of_distraction_events: int = 0
    number_of_looking_away_events: int = 0
    number_of_eye_closure_events: int = 0
    number_of_phone_events: int = 0

    longest_focused_period: float = 0.0
    longest_distraction_period: float = 0.0

    focus_score: Optional[int] = None  # None if insufficient observation (< 3.0s)

    # Legacy compatibility fields
    @property
    def focused_seconds(self) -> float:
        return self.focused_duration

    @property
    def away_seconds(self) -> float:
        return self.face_not_detected_duration

    @property
    def looking_away_seconds(self) -> float:
        return self.looking_away_duration

    @property
    def drowsy_seconds(self) -> float:
        return self.possible_drowsiness_duration

    @property
    def phone_seconds(self) -> float:
        return self.phone_detected_duration

    @property
    def distraction_count(self) -> int:
        return self.number_of_distraction_events

    def to_dict(self) -> Dict[str, Any]:
        return {
            "total_observed_seconds": round(self.total_observed_seconds, 1),
            "focused_duration": round(self.focused_duration, 1),
            "looking_away_duration": round(self.looking_away_duration, 1),
            "eyes_closed_duration": round(self.eyes_closed_duration, 1),
            "possible_drowsiness_duration": round(self.possible_drowsiness_duration, 1),
            "phone_detected_duration": round(self.phone_detected_duration, 1),
            "face_not_detected_duration": round(self.face_not_detected_duration, 1),
            "unknown_duration": round(self.unknown_duration, 1),
            "number_of_distraction_events": self.number_of_distraction_events,
            "number_of_looking_away_events": self.number_of_looking_away_events,
            "number_of_eye_closure_events": self.number_of_eye_closure_events,
            "number_of_phone_events": self.number_of_phone_events,
            "longest_focused_period": round(self.longest_focused_period, 1),
            "longest_distraction_period": round(self.longest_distraction_period, 1),
            "focus_score": self.focus_score,
            # Backward-compat keys:
            "focused_seconds": round(self.focused_duration, 1),
            "away_seconds": round(self.face_not_detected_duration, 1),
            "looking_away_seconds": round(self.looking_away_duration, 1),
            "drowsy_seconds": round(self.possible_drowsiness_duration, 1),
            "phone_seconds": round(self.phone_detected_duration, 1),
            "distraction_count": self.number_of_distraction_events,
        }


class SessionObservationAccumulator:
    """Accumulates verified real-time focus observations during a study session.

    Handles pause/resume correctly so paused time is never counted.
    """

    def __init__(self) -> None:
        self.metrics = SessionMetrics()
        self._current_focused_streak: float = 0.0
        self._current_distraction_streak: float = 0.0
        self._is_paused: bool = False
        self._last_tick_time: Optional[float] = None
        self._previous_state: str = "UNKNOWN"

    def pause(self) -> None:
        """Pause metrics accumulation."""
        self._is_paused = True
        self._last_tick_time = None

    def resume(self, now: Optional[float] = None) -> None:
        """Resume metrics accumulation."""
        self._is_paused = False
        self._last_tick_time = now if now is not None else time.time()

    @property
    def is_paused(self) -> bool:
        return self._is_paused

    def tick(self, state: str, now: Optional[float] = None) -> SessionMetrics:
        """Accumulate elapsed observation time since last tick."""
        current_time = now if now is not None else time.time()

        if self._is_paused:
            self._last_tick_time = None
            return self.metrics

        if self._last_tick_time is None:
            self._last_tick_time = current_time
            self._previous_state = state
            return self.metrics

        delta = max(0.0, min(5.0, current_time - self._last_tick_time))
        self._last_tick_time = current_time

        # Detect transition into distraction events
        is_distraction = state in (
            "LOOKING_AWAY",
            "LOOKING_DOWN",
            "LOOKING_UP",
            "POSSIBLE_DROWSINESS",
            "PHONE_DETECTED",
            "FACE_NOT_DETECTED",
        )
        was_distraction = self._previous_state in (
            "LOOKING_AWAY",
            "LOOKING_DOWN",
            "LOOKING_UP",
            "POSSIBLE_DROWSINESS",
            "PHONE_DETECTED",
            "FACE_NOT_DETECTED",
        )

        if is_distraction and not was_distraction:
            self.metrics.number_of_distraction_events += 1

            if state in ("LOOKING_AWAY", "LOOKING_DOWN", "LOOKING_UP"):
                self.metrics.number_of_looking_away_events += 1
            elif state == "POSSIBLE_DROWSINESS":
                self.metrics.number_of_eye_closure_events += 1
            elif state == "PHONE_DETECTED":
                self.metrics.number_of_phone_events += 1

        # Accumulate durations by verified state
        if state == "FOCUSED":
            self.metrics.focused_duration += delta
            self._current_focused_streak += delta
            self._current_distraction_streak = 0.0
            if self._current_focused_streak > self.metrics.longest_focused_period:
                self.metrics.longest_focused_period = self._current_focused_streak
        elif state in ("LOOKING_AWAY", "LOOKING_DOWN", "LOOKING_UP"):
            self.metrics.looking_away_duration += delta
            self._current_distraction_streak += delta
            self._current_focused_streak = 0.0
            if self._current_distraction_streak > self.metrics.longest_distraction_period:
                self.metrics.longest_distraction_period = self._current_distraction_streak
        elif state == "EYES_CLOSED":
            self.metrics.eyes_closed_duration += delta
        elif state == "POSSIBLE_DROWSINESS":
            self.metrics.possible_drowsiness_duration += delta
            self._current_distraction_streak += delta
            self._current_focused_streak = 0.0
            if self._current_distraction_streak > self.metrics.longest_distraction_period:
                self.metrics.longest_distraction_period = self._current_distraction_streak
        elif state == "PHONE_DETECTED":
            self.metrics.phone_detected_duration += delta
            self._current_distraction_streak += delta
            self._current_focused_streak = 0.0
            if self._current_distraction_streak > self.metrics.longest_distraction_period:
                self.metrics.longest_distraction_period = self._current_distraction_streak
        elif state == "FACE_NOT_DETECTED":
            self.metrics.face_not_detected_duration += delta
            self._current_distraction_streak += delta
            self._current_focused_streak = 0.0
            if self._current_distraction_streak > self.metrics.longest_distraction_period:
                self.metrics.longest_distraction_period = self._current_distraction_streak
        elif state in ("UNKNOWN", "CAMERA_ERROR", "CV_INITIALIZING", "RECOVERING", "POSSIBLE_DISTRACTION"):
            self.metrics.unknown_duration += delta

        self._previous_state = state

        # Calculate verified, deterministic Focus Score:
        # Total observed time of confirmed states (excluding unknown):
        confirmed_observed = (
            self.metrics.focused_duration
            + self.metrics.looking_away_duration
            + self.metrics.eyes_closed_duration
            + self.metrics.possible_drowsiness_duration
            + self.metrics.phone_detected_duration
            + self.metrics.face_not_detected_duration
        )
        self.metrics.total_observed_seconds = confirmed_observed + self.metrics.unknown_duration

        # If less than 3.0s of confirmed observation, score is None ("Not enough data")
        if confirmed_observed < 3.0:
            self.metrics.focus_score = None
        else:
            score = (self.metrics.focused_duration / confirmed_observed) * 100.0
            self.metrics.focus_score = max(0, min(100, int(round(score))))

        return self.metrics

    def reset(self) -> None:
        """Reset accumulator."""
        self.metrics = SessionMetrics()
        self._current_focused_streak = 0.0
        self._current_distraction_streak = 0.0
        self._is_paused = False
        self._last_tick_time = None
        self._previous_state = "UNKNOWN"
