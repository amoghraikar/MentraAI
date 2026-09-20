"""Real Focus Classification, Temporal State Machine, Alert Policy & Metrics Engine."""

from dataclasses import asdict, dataclass
from enum import Enum
import time
from typing import Any, Dict, Optional

from .alert_policy import AlertPolicy, FocusAlert
from .metrics import SessionMetrics, SessionObservationAccumulator
from .temporal import TemporalConditionTracker


class FocusState(str, Enum):
    FOCUSED = "FOCUSED"
    POSSIBLE_DISTRACTION = "POSSIBLE_DISTRACTION"
    LOOKING_AWAY = "LOOKING_AWAY"
    LOOKING_DOWN = "LOOKING_DOWN"
    LOOKING_UP = "LOOKING_UP"
    EYES_CLOSED = "EYES_CLOSED"
    POSSIBLE_DROWSINESS = "POSSIBLE_DROWSINESS"
    PHONE_DETECTED = "PHONE_DETECTED"
    FACE_NOT_DETECTED = "FACE_NOT_DETECTED"
    RECOVERING = "RECOVERING"
    UNKNOWN = "UNKNOWN"
    CAMERA_ERROR = "CAMERA_ERROR"
    CV_INITIALIZING = "CV_INITIALIZING"


class ConfidenceLevel(str, Enum):
    HIGH_CONFIDENCE = "HIGH_CONFIDENCE"
    MEDIUM_CONFIDENCE = "MEDIUM_CONFIDENCE"
    LOW_CONFIDENCE = "LOW_CONFIDENCE"
    UNKNOWN = "UNKNOWN"


@dataclass
class BehaviorObservation:
    timestamp: float
    focus_state: FocusState
    confidence_level: ConfidenceLevel
    active_alert: Optional[FocusAlert] = None
    session_metrics: Optional[SessionMetrics] = None


class FocusBehaviorEngine:
    """Temporal state machine combining facial, eye, pose, and phone signals

    to produce honest focus states, non-spammy alerts, and verified focus scores.
    """

    def __init__(
        self,
        face_absent_threshold_seconds: float = 2.0,
        looking_away_threshold_seconds: float = 1.3,
        looking_down_threshold_seconds: float = 1.5,
        phone_threshold_seconds: float = 1.0,
        recovery_duration_seconds: float = 0.5,
        alert_cooldown_seconds: float = 8.0,
    ) -> None:
        # Temporal condition debouncers
        self.face_absent_tracker = TemporalConditionTracker(face_absent_threshold_seconds)
        self.looking_away_tracker = TemporalConditionTracker(looking_away_threshold_seconds)
        self.looking_down_tracker = TemporalConditionTracker(looking_down_threshold_seconds)
        self.phone_tracker = TemporalConditionTracker(phone_threshold_seconds)

        self.recovery_duration = recovery_duration_seconds
        self.recovery_tracker = TemporalConditionTracker(recovery_duration_seconds)

        # Central alert policy
        self.alert_policy = AlertPolicy(default_cooldown_seconds=alert_cooldown_seconds)

        # Cumulative session metrics accumulator
        self.accumulator = SessionObservationAccumulator()

        # Internal state
        self._current_state = FocusState.UNKNOWN
        self._was_distracted = False

    def pause(self) -> None:
        """Pause monitoring and time accumulation."""
        self.accumulator.pause()

    def resume(self, now: Optional[float] = None) -> None:
        """Resume monitoring."""
        self.accumulator.resume(now)

    @property
    def is_paused(self) -> bool:
        return self.accumulator.is_paused

    def compute_confidence(
        self,
        face_present: bool,
        face_confidence: float,
        camera_quality_status: str,
        landmark_quality: float,
    ) -> ConfidenceLevel:
        """Determine honest detector confidence from real signals."""
        if not face_present or camera_quality_status == "UNAVAILABLE":
            return ConfidenceLevel.UNKNOWN

        if camera_quality_status == "GOOD" and face_confidence >= 0.65 and landmark_quality >= 0.9:
            return ConfidenceLevel.HIGH_CONFIDENCE
        elif camera_quality_status in ("GOOD", "FAIR") and face_confidence >= 0.4:
            return ConfidenceLevel.MEDIUM_CONFIDENCE
        else:
            return ConfidenceLevel.LOW_CONFIDENCE

    def update(
        self,
        face_present: bool,
        is_drowsy: bool,
        orientation: str,  # NORMAL_FORWARD, POSSIBLE_LOOKING_AWAY, LOOKING_AWAY, LOOKING_DOWN, LOOKING_UP, UNKNOWN
        phone_detected: bool,
        face_confidence: float = 0.9,
        camera_quality_status: str = "GOOD",
        landmark_quality: float = 1.0,
        eye_state: str = "NORMAL_OPEN",
        timestamp: Optional[float] = None,
    ) -> BehaviorObservation:
        """Ingest instantaneous signals from detectors and run temporal state transitions."""
        now = timestamp if timestamp is not None else time.time()

        confidence = self.compute_confidence(
            face_present=face_present,
            face_confidence=face_confidence,
            camera_quality_status=camera_quality_status,
            landmark_quality=landmark_quality,
        )

        alert: Optional[FocusAlert] = None

        # 0. Camera Feed / Detector Failure
        if camera_quality_status == "UNAVAILABLE":
            self._current_state = FocusState.CAMERA_ERROR
            metrics = self.accumulator.tick(self._current_state.value, now)
            return BehaviorObservation(now, self._current_state, confidence, None, metrics)

        # 1. Face Presence Evaluation
        absent_dur = self.face_absent_tracker.update(not face_present, now)
        if not face_present:
            # Reset other trackers
            self.looking_away_tracker.reset()
            self.looking_down_tracker.reset()
            self.phone_tracker.reset()
            self.recovery_tracker.reset()

            if self.face_absent_tracker.is_triggered:
                self._current_state = FocusState.FACE_NOT_DETECTED
                self._was_distracted = True
                alert = self.alert_policy.create_alert("FACE_NOT_DETECTED", now)
            else:
                # Brief absence: do not jump to distraction alert yet
                self._current_state = FocusState.POSSIBLE_DISTRACTION

            metrics = self.accumulator.tick(self._current_state.value, now)
            return BehaviorObservation(now, self._current_state, confidence, alert, metrics)

        # 2. Phone Detection Evaluation (Highest priority physical distraction)
        phone_dur = self.phone_tracker.update(phone_detected, now)
        if phone_detected:
            if self.phone_tracker.is_triggered:
                self._current_state = FocusState.PHONE_DETECTED
                self._was_distracted = True
                alert = self.alert_policy.create_alert("PHONE_DETECTED", now)
            else:
                self._current_state = FocusState.POSSIBLE_DISTRACTION

            metrics = self.accumulator.tick(self._current_state.value, now)
            return BehaviorObservation(now, self._current_state, confidence, alert, metrics)

        # 3. Drowsiness / Eye Closure Evaluation
        if is_drowsy:
            self._current_state = FocusState.POSSIBLE_DROWSINESS
            self._was_distracted = True
            alert = self.alert_policy.create_alert("POSSIBLE_DROWSINESS", now)
            metrics = self.accumulator.tick(self._current_state.value, now)
            return BehaviorObservation(now, self._current_state, confidence, alert, metrics)
        elif eye_state == "EYES_CLOSED":
            # Momentary closure past blink threshold but before sustained drowsiness
            self._current_state = FocusState.EYES_CLOSED
            metrics = self.accumulator.tick(self._current_state.value, now)
            return BehaviorObservation(now, self._current_state, confidence, None, metrics)

        # 4. Head Pose / Gaze Deviation Evaluation
        if orientation == "LOOKING_AWAY":
            self.looking_down_tracker.reset()
            self.looking_away_tracker.update(True, now)

            if self.looking_away_tracker.is_triggered:
                self._current_state = FocusState.LOOKING_AWAY
                self._was_distracted = True
                alert = self.alert_policy.create_alert("LOOKING_AWAY", now)
            else:
                self._current_state = FocusState.POSSIBLE_DISTRACTION

            metrics = self.accumulator.tick(self._current_state.value, now)
            return BehaviorObservation(now, self._current_state, confidence, alert, metrics)

        elif orientation == "LOOKING_DOWN":
            self.looking_away_tracker.reset()
            self.looking_down_tracker.update(True, now)

            if self.looking_down_tracker.is_triggered:
                self._current_state = FocusState.LOOKING_DOWN
                self._was_distracted = True
                alert = self.alert_policy.create_alert("LOOKING_DOWN", now)
            else:
                self._current_state = FocusState.POSSIBLE_DISTRACTION

            metrics = self.accumulator.tick(self._current_state.value, now)
            return BehaviorObservation(now, self._current_state, confidence, alert, metrics)

        elif orientation == "POSSIBLE_LOOKING_AWAY":
            # Natural movement / edge scanning: classified as possible distraction, NO ALERT
            self.looking_away_tracker.reset()
            self.looking_down_tracker.reset()
            self._current_state = FocusState.POSSIBLE_DISTRACTION
            metrics = self.accumulator.tick(self._current_state.value, now)
            return BehaviorObservation(now, self._current_state, confidence, None, metrics)

        # Reset look-away trackers when orientation is normal
        self.looking_away_tracker.reset()
        self.looking_down_tracker.reset()

        # 5. Recovery State: if user just returned from a confirmed distraction state
        if self._was_distracted:
            rec_dur = self.recovery_tracker.update(True, now)
            if self.recovery_tracker.is_triggered:
                self._was_distracted = False
                self.recovery_tracker.reset()
                self._current_state = FocusState.FOCUSED
            else:
                self._current_state = FocusState.RECOVERING

            metrics = self.accumulator.tick(self._current_state.value, now)
            return BehaviorObservation(now, self._current_state, confidence, None, metrics)

        # 6. Default Normal State: FOCUSED
        self._current_state = FocusState.FOCUSED
        metrics = self.accumulator.tick(self._current_state.value, now)
        return BehaviorObservation(now, self._current_state, confidence, None, metrics)

    def reset(self) -> None:
        """Reset temporal state machines, alerts, and accumulators."""
        self.face_absent_tracker.reset()
        self.looking_away_tracker.reset()
        self.looking_down_tracker.reset()
        self.phone_tracker.reset()
        self.recovery_tracker.reset()
        self.alert_policy.reset()
        self.accumulator.reset()
        self._current_state = FocusState.UNKNOWN
        self._was_distracted = False


__all__ = [
    "FocusState",
    "ConfidenceLevel",
    "FocusAlert",
    "SessionMetrics",
    "SessionObservationAccumulator",
    "BehaviorObservation",
    "FocusBehaviorEngine",
    "TemporalConditionTracker",
    "AlertPolicy",
]
