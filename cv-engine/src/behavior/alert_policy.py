"""Centralized Alert Policy Module.

Enforces alert thresholds, cooldowns, recovery rules, and calm user-friendly messages.
"""

from dataclasses import dataclass
import time
from typing import Dict, Optional


@dataclass
class FocusAlert:
    id: str
    type: str  # e.g. "LOOKING_AWAY", "POSSIBLE_DROWSINESS", "PHONE_DETECTED", "FACE_NOT_DETECTED"
    timestamp: float
    message: str
    severity: str = "warning"  # "info", "warning", "critical"


class AlertPolicy:
    """Centralized policy manager for focus alerts.

    Ensures alerts are actionable, calm, non-medical, and not spammy.
    """

    MESSAGES = {
        "LOOKING_AWAY": "Eyes on the screen.",
        "POSSIBLE_DROWSINESS": "Take a short break if you need one.",
        "PHONE_DETECTED": "Put the phone aside and get back to your session.",
        "FACE_NOT_DETECTED": "Make sure you're visible to the camera.",
        "LOOKING_DOWN": "Head tilted down. Keep eyes on your study material.",
    }

    SEVERITIES = {
        "LOOKING_AWAY": "info",
        "POSSIBLE_DROWSINESS": "warning",
        "PHONE_DETECTED": "critical",
        "FACE_NOT_DETECTED": "warning",
        "LOOKING_DOWN": "info",
    }

    def __init__(
        self,
        default_cooldown_seconds: float = 8.0,
        drowsiness_cooldown_seconds: float = 10.0,
    ) -> None:
        self.default_cooldown = default_cooldown_seconds
        self.drowsiness_cooldown = drowsiness_cooldown_seconds
        self._last_alert_times: Dict[str, float] = {}

    def should_alert(self, alert_type: str, now: Optional[float] = None) -> bool:
        """Check if cooldown has expired for this alert type."""
        current = now if now is not None else time.time()
        last_time = self._last_alert_times.get(alert_type)
        if last_time is None:
            return True

        cooldown = (
            self.drowsiness_cooldown
            if alert_type == "POSSIBLE_DROWSINESS"
            else self.default_cooldown
        )
        return (current - last_time) >= cooldown

    def create_alert(self, alert_type: str, now: Optional[float] = None) -> Optional[FocusAlert]:
        """Generate alert if permitted by cooldown policy."""
        current = now if now is not None else time.time()
        if not self.should_alert(alert_type, current):
            return None

        self._last_alert_times[alert_type] = current
        msg = self.MESSAGES.get(alert_type, "Please stay focused on your study material.")
        sev = self.SEVERITIES.get(alert_type, "warning")

        return FocusAlert(
            id=f"alt_{int(current * 1000)}",
            type=alert_type,
            timestamp=current,
            message=msg,
            severity=sev,
        )

    def reset(self) -> None:
        """Clear all cooldown records."""
        self._last_alert_times.clear()
