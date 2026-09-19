"""Real Focus Classification, Temporal Smoothing, Focus Scoring & Alert Engine."""

from dataclasses import dataclass, field
from enum import Enum
import time
from typing import Dict, List, Optional


class FocusState(str, Enum):
    FOCUSED = "FOCUSED"
    LOOKING_AWAY = "LOOKING_AWAY"
    LOOKING_DOWN = "LOOKING_DOWN"
    LOOKING_UP = "LOOKING_UP"
    EYES_CLOSED = "EYES_CLOSED"
    POSSIBLE_DROWSINESS = "POSSIBLE_DROWSINESS"
    PHONE_DETECTED = "PHONE_DETECTED"
    FACE_NOT_DETECTED = "FACE_NOT_DETECTED"
    UNKNOWN = "UNKNOWN"


@dataclass
class FocusAlert:
    id: str
    type: str  # e.g. "PHONE_DETECTED", "LOOKING_AWAY", "POSSIBLE_DROWSINESS", "FACE_NOT_DETECTED"
    timestamp: float
    message: str
    severity: str = "warning"  # "info", "warning", "critical"


@dataclass
class SessionMetrics:
    total_observed_seconds: float = 0.0
    focused_seconds: float = 0.0
    away_seconds: float = 0.0
    looking_away_seconds: float = 0.0
    looking_down_seconds: float = 0.0
    drowsy_seconds: float = 0.0
    phone_seconds: float = 0.0
    focus_score: int = 100
    distraction_count: int = 0
    drowsiness_count: int = 0
    phone_count: int = 0


@dataclass
class BehaviorObservation:
    timestamp: float
    focus_state: FocusState
    active_alert: Optional[FocusAlert] = None
    session_metrics: Optional[SessionMetrics] = None


class FocusBehaviorEngine:
    """Combines facial, eye, pose, and object signals through temporal debouncing

    to produce honest focus states, non-spammy alerts, and verified focus scores.
    """

    def __init__(
        self,
        face_absent_threshold_seconds: float = 2.0,
        looking_away_threshold_seconds: float = 1.2,
        looking_down_threshold_seconds: float = 1.2,
        phone_threshold_seconds: float = 1.0,
        alert_cooldown_seconds: float = 6.0,
    ) -> None:
        self.face_absent_threshold = face_absent_threshold_seconds
        self.looking_away_threshold = looking_away_threshold_seconds
        self.looking_down_threshold = looking_down_threshold_seconds
        self.phone_threshold = phone_threshold_seconds
        self.alert_cooldown = alert_cooldown_seconds

        # State timestamps for temporal debouncing
        self._face_absent_start: Optional[float] = None
        self._looking_away_start: Optional[float] = None
        self._looking_down_start: Optional[float] = None
        self._phone_start: Optional[float] = None

        # Cooldown trackers
        self._last_alert_time: Dict[str, float] = {}

        # Cumulative session metrics
        self.metrics = SessionMetrics()
        self._last_tick_time: Optional[float] = None
        self._current_state = FocusState.UNKNOWN

    def update(
        self,
        face_present: bool,
        is_drowsy: bool,
        orientation: str,  # "NORMAL_FORWARD", "LOOKING_AWAY", "LOOKING_DOWN", "LOOKING_UP", "UNKNOWN"
        phone_detected: bool,
        timestamp: Optional[float] = None,
    ) -> BehaviorObservation:
        """Ingest instantaneous signals from detectors and apply temporal debouncing."""
        now = timestamp if timestamp is not None else time.time()

        # Update elapsed time for session metrics
        if self._last_tick_time is not None:
            delta = max(0.0, min(10.0, now - self._last_tick_time))
            self._accumulate_metrics(delta, self._current_state)
        self._last_tick_time = now

        # 1. Face Presence Evaluation
        if not face_present:
            self._looking_away_start = None
            self._looking_down_start = None
            self._phone_start = None

            if self._face_absent_start is None:
                self._face_absent_start = now

            absent_duration = now - self._face_absent_start
            if absent_duration >= self.face_absent_threshold:
                self._current_state = FocusState.FACE_NOT_DETECTED
                alert = self._create_alert(
                    alert_type="FACE_NOT_DETECTED",
                    message="No face detected in camera view.",
                    now=now,
                    severity="warning",
                )
                return BehaviorObservation(now, self._current_state, alert, self.metrics)
            else:
                return BehaviorObservation(now, self._current_state, None, self.metrics)

        # Face is confirmed present
        self._face_absent_start = None

        # 2. Phone Detection Evaluation (Highest priority distraction)
        if phone_detected:
            if self._phone_start is None:
                self._phone_start = now

            if now - self._phone_start >= self.phone_threshold:
                self._current_state = FocusState.PHONE_DETECTED
                alert = self._create_alert(
                    alert_type="PHONE_DETECTED",
                    message="Phone detected in study view. Put device away to stay focused.",
                    now=now,
                    severity="critical",
                )
                if alert:
                    self.metrics.phone_count += 1
                return BehaviorObservation(now, self._current_state, alert, self.metrics)
        else:
            self._phone_start = None

        # 3. Drowsiness / Eye Closure Evaluation
        if is_drowsy:
            self._current_state = FocusState.POSSIBLE_DROWSINESS
            alert = self._create_alert(
                alert_type="POSSIBLE_DROWSINESS",
                message="Prolonged eye closure detected. Take a quick stretch or sip of water.",
                now=now,
                severity="warning",
            )
            if alert:
                self.metrics.drowsiness_count += 1
            return BehaviorObservation(now, self._current_state, alert, self.metrics)

        # 4. Head Pose / Gaze Evaluation
        if orientation == "LOOKING_AWAY":
            self._looking_down_start = None
            if self._looking_away_start is None:
                self._looking_away_start = now

            if now - self._looking_away_start >= self.looking_away_threshold:
                self._current_state = FocusState.LOOKING_AWAY
                alert = self._create_alert(
                    alert_type="LOOKING_AWAY",
                    message="Gaze directed away from study screen. Refocus on your material.",
                    now=now,
                    severity="info",
                )
                if alert:
                    self.metrics.distraction_count += 1
                return BehaviorObservation(now, self._current_state, alert, self.metrics)

        elif orientation == "LOOKING_DOWN":
            self._looking_away_start = None
            if self._looking_down_start is None:
                self._looking_down_start = now

            if now - self._looking_down_start >= self.looking_down_threshold:
                self._current_state = FocusState.LOOKING_DOWN
                alert = self._create_alert(
                    alert_type="LOOKING_DOWN",
                    message="Head tilted down. Keep your eyes on the study material.",
                    now=now,
                    severity="info",
                )
                if alert:
                    self.metrics.distraction_count += 1
                return BehaviorObservation(now, self._current_state, alert, self.metrics)

        else:
            # NORMAL_FORWARD
            self._looking_away_start = None
            self._looking_down_start = None

        # 5. Default State: FOCUSED
        self._current_state = FocusState.FOCUSED
        return BehaviorObservation(now, self._current_state, None, self.metrics)

    def _accumulate_metrics(self, delta: float, state: FocusState) -> None:
        """Increment observed durations and recalculate true focus score."""
        self.metrics.total_observed_seconds += delta

        if state == FocusState.FOCUSED:
            self.metrics.focused_seconds += delta
        elif state == FocusState.FACE_NOT_DETECTED:
            self.metrics.away_seconds += delta
        elif state == FocusState.LOOKING_AWAY:
            self.metrics.looking_away_seconds += delta
        elif state == FocusState.LOOKING_DOWN:
            self.metrics.looking_down_seconds += delta
        elif state == FocusState.POSSIBLE_DROWSINESS:
            self.metrics.drowsy_seconds += delta
        elif state == FocusState.PHONE_DETECTED:
            self.metrics.phone_seconds += delta

        # Verified mathematical Focus Score: focused time / total observed time
        if self.metrics.total_observed_seconds > 0:
            ratio = self.metrics.focused_seconds / self.metrics.total_observed_seconds
            self.metrics.focus_score = int(round(ratio * 100))
        else:
            self.metrics.focus_score = 100

    def _create_alert(
        self,
        alert_type: str,
        message: str,
        now: float,
        severity: str = "warning",
    ) -> Optional[FocusAlert]:
        """Produce alert only if cooldown has expired for this alert type."""
        last_time = self._last_alert_time.get(alert_type)
        if last_time is not None and (now - last_time) < self.alert_cooldown:
            return None

        self._last_alert_time[alert_type] = now
        return FocusAlert(
            id=f"alt_{int(now * 1000)}",
            type=alert_type,
            timestamp=now,
            message=message,
            severity=severity,
        )

    def reset(self) -> None:
        """Reset temporal buffers, cooldowns, and cumulative metrics."""
        self._face_absent_start = None
        self._looking_away_start = None
        self._looking_down_start = None
        self._phone_start = None
        self._last_alert_time.clear()
        self.metrics = SessionMetrics()
        self._last_tick_time = None
        self._current_state = FocusState.UNKNOWN
