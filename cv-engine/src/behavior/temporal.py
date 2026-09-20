"""Reusable Temporal Condition Tracker for CV Event Debouncing."""

import time
from typing import Optional


class TemporalConditionTracker:
    """Tracks the continuous duration of an observed condition.

    Prevents instantaneous camera noise, natural blinks, or minor twitches
    from prematurely triggering state changes or alerts.
    """

    def __init__(self, trigger_threshold_seconds: float) -> None:
        self.threshold = trigger_threshold_seconds
        self._start_time: Optional[float] = None
        self._last_active_time: Optional[float] = None

    def update(self, active: bool, now: Optional[float] = None) -> float:
        """Update the condition state and return active duration in seconds."""
        current = now if now is not None else time.time()

        if active:
            if self._start_time is None:
                self._start_time = current
            self._last_active_time = current
            return current - self._start_time
        else:
            self._start_time = None
            return 0.0

    @property
    def is_triggered(self) -> bool:
        """Check if condition has persisted longer than threshold."""
        if self._start_time is None or self._last_active_time is None:
            return False
        return (self._last_active_time - self._start_time) >= self.threshold

    @property
    def elapsed_seconds(self) -> float:
        if self._start_time is None or self._last_active_time is None:
            return 0.0
        return max(0.0, self._last_active_time - self._start_time)

    def reset(self) -> None:
        self._start_time = None
        self._last_active_time = None
