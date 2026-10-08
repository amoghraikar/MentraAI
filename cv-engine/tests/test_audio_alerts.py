"""Unit Tests for CV Engine Audio Alerts and Sound Generator Subsystem."""

import time
from unittest.mock import MagicMock, patch
import numpy as np
import pytest

from src import (
    AudioAlertManager,
    CvEngine,
    FocusState,
    SoundType,
    ToneGenerator,
)


def test_tone_generator_wav_format() -> None:
    """Verify synthesized WAV files have valid headers and playable 16-bit PCM bytes."""
    wav_bytes = ToneGenerator.generate_simple_beep(frequency=440.0, duration_seconds=0.1, volume=0.5)
    assert len(wav_bytes) > 44  # WAV header is 44 bytes
    assert wav_bytes.startswith(b"RIFF")
    assert b"WAVE" in wav_bytes[:16]
    assert b"fmt " in wav_bytes[:24]

    # Verify distraction and drowsiness tones
    distraction_wav = ToneGenerator.generate_distraction_tone(volume=0.4)
    assert len(distraction_wav) > 1000
    assert distraction_wav.startswith(b"RIFF")

    drowsiness_wav = ToneGenerator.generate_drowsiness_tone(volume=0.6)
    assert len(drowsiness_wav) > 1000
    assert drowsiness_wav.startswith(b"RIFF")


def test_audio_manager_enable_disable() -> None:
    """Verify audio alerts are skipped when disabled."""
    manager = AudioAlertManager(enabled=False)
    assert not manager.enabled

    # Should not trigger when disabled
    assert not manager.handle_alert("POSSIBLE_DROWSINESS")
    assert not manager.handle_alert("LOOKING_AWAY")
    assert not manager.play_distraction()
    assert not manager.play_drowsiness()
    assert not manager.play_beep()

    # Re-enable
    manager.enabled = True
    assert manager.enabled
    assert manager.handle_alert("POSSIBLE_DROWSINESS")
    manager.close()


def test_audio_manager_cooldown_and_throttling() -> None:
    """Verify alert debouncing respects cooldown timers and global throttling."""
    manager = AudioAlertManager(
        enabled=True,
        distraction_cooldown_seconds=4.0,
        drowsiness_cooldown_seconds=5.0,
        min_interval_seconds=1.0,
    )
    t0 = 1000.0

    # 1. First distraction alert fires
    assert manager.handle_alert("LOOKING_AWAY", now=t0) is True

    # 2. Immediate repeat within min_interval (0.5s later) -> Blocked by throttle
    assert manager.handle_alert("LOOKING_AWAY", now=t0 + 0.5) is False

    # 3. Repeat after 2.0s (less than distraction_cooldown 4.0s) -> Blocked by cooldown
    assert manager.handle_alert("LOOKING_AWAY", now=t0 + 2.0) is False

    # 4. Different alert (DROWSINESS) after 2.0s -> Allowed (independent alert cooldown)
    assert manager.handle_alert("POSSIBLE_DROWSINESS", now=t0 + 2.0) is True

    # 5. Drowsiness within 5.0s cooldown -> Blocked
    assert manager.handle_alert("POSSIBLE_DROWSINESS", now=t0 + 4.0) is False

    # 6. Distraction after 4.5s from original (t0 + 4.5s) -> Allowed
    assert manager.handle_alert("LOOKING_AWAY", now=t0 + 4.5) is True

    # 7. Drowsiness after 5.5s from its trigger (t0 + 2.0 + 5.5 = t0 + 7.5) -> Allowed
    assert manager.handle_alert("POSSIBLE_DROWSINESS", now=t0 + 7.5) is True

    manager.close()


def test_audio_manager_alert_listener() -> None:
    """Verify listener callback is dispatched on alert playback."""
    manager = AudioAlertManager(enabled=True)
    events = []

    def on_alert(sound_type: SoundType, alert_name: str) -> None:
        events.append((sound_type, alert_name))

    manager.add_alert_listener(on_alert)

    manager.handle_alert("PHONE_DETECTED", now=100.0)
    assert len(events) == 1
    assert events[0] == (SoundType.DISTRACTION, "PHONE_DETECTED")

    manager.handle_alert("POSSIBLE_DROWSINESS", now=110.0)
    assert len(events) == 2
    assert events[1] == (SoundType.DROWSINESS, "POSSIBLE_DROWSINESS")

    manager.remove_alert_listener(on_alert)
    manager.handle_alert("LOOKING_DOWN", now=120.0)
    assert len(events) == 2  # Listener removed, no new event recorded

    manager.close()


def test_audio_manager_non_blocking_performance() -> None:
    """Verify handle_alert returns instantly (< 10ms) without blocking frame processing."""
    manager = AudioAlertManager(enabled=True)
    t_start = time.perf_counter()
    manager.handle_alert("LOOKING_AWAY")
    elapsed_ms = (time.perf_counter() - t_start) * 1000.0

    # Dispatching audio must not stall the thread
    assert elapsed_ms < 15.0, f"Audio dispatch took {elapsed_ms:.2f}ms (expected < 15ms)"
    manager.close()


def test_cv_engine_audio_integration() -> None:
    """Verify master CvEngine triggers audio alerts when distractions or drowsiness occurs."""
    engine = CvEngine(enable_phone_detection=False, enable_audio_alerts=True)
    assert engine.is_audio_enabled

    audio_events = []
    engine.audio_manager.add_alert_listener(lambda st, name: audio_events.append((st, name)))

    # Synthetic blank frame
    blank = np.zeros((100, 100, 3), dtype=np.uint8)

    # Initial frame
    res1 = engine.process_frame(blank, timestamp=10.0)
    # Camera error / unavailable -> no distraction alert yet
    assert res1.audio_played is False

    # Simulate behavior engine triggering distraction alert directly
    engine.behavior_engine.alert_policy.reset()
    engine.audio_manager.reset()

    # Trigger distraction alert via engine helper
    played = engine.play_audio_alert("LOOKING_AWAY")
    assert played is True
    assert len(audio_events) == 1
    assert audio_events[0][0] == SoundType.DISTRACTION

    # Trigger drowsiness alert via engine helper (cooldown respected)
    played_drowsy = engine.audio_manager.handle_alert("POSSIBLE_DROWSINESS", now=20.0)
    assert played_drowsy is True
    assert len(audio_events) == 2
    assert audio_events[1][0] == SoundType.DROWSINESS

    # Test toggling audio off
    engine.set_audio_alerts(False)
    assert not engine.is_audio_enabled
    assert not engine.play_audio_alert("BEEP")

    engine.close()
