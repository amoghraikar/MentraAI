"""Cross-platform Audio Alert Manager for Mentra CV Engine.

Executes asynchronous, non-blocking audio alerts (beeps and tones)
whenever distraction or drowsiness is detected by the focus state machine.
"""

from collections import deque
import logging
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from typing import Callable, Deque, Dict, Optional, Tuple

from .tone_generator import SoundType, ToneGenerator

logger = logging.getLogger("mentra.cv.audio")


class AudioAlertManager:
    """Manages audio cue playback for CV Engine with debouncing, non-blocking execution,

    and cross-platform audio fallback support.
    """

    def __init__(
        self,
        enabled: bool = True,
        volume: float = 0.6,
        distraction_cooldown_seconds: float = 4.0,
        drowsiness_cooldown_seconds: float = 5.0,
        min_interval_seconds: float = 1.0,
        sound_dir: Optional[str] = None,
    ) -> None:
        self.enabled = enabled
        self._volume = max(0.0, min(1.0, volume))
        self.distraction_cooldown = distraction_cooldown_seconds
        self.drowsiness_cooldown = drowsiness_cooldown_seconds
        self.min_interval = min_interval_seconds

        # Platform detection
        self._platform = sys.platform
        self._afplay_bin = shutil.which("afplay")
        self._aplay_bin = shutil.which("aplay")
        self._paplay_bin = shutil.which("paplay")
        self._pwplay_bin = shutil.which("pw-play")
        self._ffplay_bin = shutil.which("ffplay")

        # Sound file cache
        if sound_dir:
            self._cache_dir = Path(sound_dir)
            self._cache_dir.mkdir(parents=True, exist_ok=True)
            self._is_temp_dir = False
        else:
            self._cache_dir = Path(tempfile.mkdtemp(prefix="mentra_cv_sounds_"))
            self._is_temp_dir = True

        self._sound_paths: Dict[SoundType, Path] = {}
        self._lock = threading.Lock()
        self._last_alert_times: Dict[str, float] = {}
        self._last_played_time: float = 0.0

        # Optional listener callback invoked whenever an alert sound plays: fn(sound_type: SoundType, alert_name: str)
        self._alert_listeners: Deque[Callable[[SoundType, str], None]] = deque()

        # Initialize default audio assets
        self._init_audio_assets()

    def _init_audio_assets(self) -> None:
        """Pre-generate synthesized WAV waveforms to disk for low-latency playback."""
        try:
            # Distraction tone
            distract_wav = ToneGenerator.generate_distraction_tone(volume=self._volume)
            distract_path = self._cache_dir / "distraction.wav"
            distract_path.write_bytes(distract_wav)
            self._sound_paths[SoundType.DISTRACTION] = distract_path

            # Drowsiness tone
            drowsy_wav = ToneGenerator.generate_drowsiness_tone(volume=self._volume)
            drowsy_path = self._cache_dir / "drowsiness.wav"
            drowsy_path.write_bytes(drowsy_wav)
            self._sound_paths[SoundType.DROWSINESS] = drowsy_path

            # Standard beep
            beep_wav = ToneGenerator.generate_simple_beep(frequency=880.0, volume=self._volume)
            beep_path = self._cache_dir / "beep.wav"
            beep_path.write_bytes(beep_wav)
            self._sound_paths[SoundType.BEEP] = beep_path
        except Exception as e:
            logger.warning("Could not pre-synthesize audio assets: %s", e)

    @property
    def volume(self) -> float:
        return self._volume

    @volume.setter
    def volume(self, val: float) -> None:
        self._volume = max(0.0, min(1.0, val))
        self._init_audio_assets()

    def add_alert_listener(self, callback: Callable[[SoundType, str], None]) -> None:
        """Add an event listener to be notified when audio plays."""
        self._alert_listeners.append(callback)

    def remove_alert_listener(self, callback: Callable[[SoundType, str], None]) -> None:
        """Remove a previously added listener."""
        try:
            self._alert_listeners.remove(callback)
        except ValueError:
            pass

    def should_play(self, alert_name: str, sound_type: SoundType, now: Optional[float] = None) -> bool:
        """Check whether audio should play based on enabled state and cooldown timers."""
        if not self.enabled:
            return False

        current = now if now is not None else time.time()

        # Global throttle to prevent overlapping sounds
        if self._last_played_time > 0:
            elapsed_last = current - self._last_played_time
            if 0 <= elapsed_last < self.min_interval:
                return False

        last_time = self._last_alert_times.get(alert_name)
        if last_time is None:
            return True

        elapsed_alert = current - last_time
        if elapsed_alert < 0:
            # Clock jump or reset
            return True

        cooldown = (
            self.drowsiness_cooldown
            if sound_type == SoundType.DROWSINESS
            else self.distraction_cooldown
        )
        return elapsed_alert >= cooldown

    def handle_alert(self, alert_type: str, now: Optional[float] = None) -> bool:
        """Route a FocusAlert type into the appropriate audio cue.

        Supported alert types:
          - Drowsiness: POSSIBLE_DROWSINESS, EYES_CLOSED
          - Distraction: LOOKING_AWAY, PHONE_DETECTED, FACE_NOT_DETECTED, LOOKING_DOWN, POSSIBLE_DISTRACTION
        """
        if not self.enabled or not alert_type:
            return False

        current = now if now is not None else time.time()
        sound_type = self._map_alert_to_sound_type(alert_type)
        if not sound_type:
            return False

        with self._lock:
            if not self.should_play(alert_type, sound_type, current):
                return False

            self._last_alert_times[alert_type] = current
            self._last_played_time = current

        # Asynchronously dispatch sound
        self._dispatch_sound_async(sound_type, alert_type)
        return True

    def play_distraction(self, alert_name: str = "DISTRACTION_MANUAL", now: Optional[float] = None) -> bool:
        """Play distraction alert sound directly (respects cooldown)."""
        return self._trigger_direct(SoundType.DISTRACTION, alert_name, now)

    def play_drowsiness(self, alert_name: str = "DROWSINESS_MANUAL", now: Optional[float] = None) -> bool:
        """Play drowsiness alert sound directly (respects cooldown)."""
        return self._trigger_direct(SoundType.DROWSINESS, alert_name, now)

    def play_beep(
        self,
        frequency: float = 880.0,
        duration_seconds: float = 0.18,
        alert_name: str = "BEEP_MANUAL",
        now: Optional[float] = None,
    ) -> bool:
        """Play a simple sine beep tone."""
        if not self.enabled:
            return False

        current = now if now is not None else time.time()
        with self._lock:
            if (current - self._last_played_time) < self.min_interval:
                return False
            self._last_played_time = current
            self._last_alert_times[alert_name] = current

        # If custom freq, generate on the fly
        if frequency != 880.0 or duration_seconds != 0.18:
            def _play_custom() -> None:
                try:
                    wav_data = ToneGenerator.generate_simple_beep(
                        frequency=frequency,
                        duration_seconds=duration_seconds,
                        volume=self._volume,
                    )
                    temp_wav = self._cache_dir / f"custom_{int(frequency)}_{int(duration_seconds*1000)}.wav"
                    temp_wav.write_bytes(wav_data)
                    self._play_file_sync(temp_wav)
                except Exception as e:
                    logger.debug("Custom beep playback failed: %s", e)
                    self._play_bell_fallback()

            threading.Thread(target=_play_custom, daemon=True, name="cv_audio_custom_beep").start()
            self._notify_listeners(SoundType.BEEP, alert_name)
            return True

        self._dispatch_sound_async(SoundType.BEEP, alert_name)
        return True

    def _trigger_direct(self, sound_type: SoundType, alert_name: str, now: Optional[float] = None) -> bool:
        if not self.enabled:
            return False

        current = now if now is not None else time.time()
        with self._lock:
            if not self.should_play(alert_name, sound_type, current):
                return False
            self._last_alert_times[alert_name] = current
            self._last_played_time = current

        self._dispatch_sound_async(sound_type, alert_name)
        return True

    def _map_alert_to_sound_type(self, alert_type: str) -> Optional[SoundType]:
        """Map behavior engine alert string to SoundType."""
        upper = alert_type.upper()
        if upper in ("POSSIBLE_DROWSINESS", "DROWSINESS", "EYES_CLOSED"):
            return SoundType.DROWSINESS
        elif upper in (
            "LOOKING_AWAY",
            "PHONE_DETECTED",
            "FACE_NOT_DETECTED",
            "LOOKING_DOWN",
            "LOOKING_UP",
            "POSSIBLE_DISTRACTION",
            "DISTRACTION",
        ):
            return SoundType.DISTRACTION
        elif upper == "BEEP":
            return SoundType.BEEP
        return None

    def _dispatch_sound_async(self, sound_type: SoundType, alert_name: str) -> None:
        """Spawn daemon thread to play audio asynchronously without blocking CV frame processing."""
        sound_file = self._sound_paths.get(sound_type)

        def _worker() -> None:
            try:
                if sound_file and sound_file.is_file():
                    self._play_file_sync(sound_file)
                else:
                    self._play_bell_fallback()
            except Exception as e:
                logger.debug("Audio playback execution exception: %s", e)
                self._play_bell_fallback()

        thread = threading.Thread(
            target=_worker,
            daemon=True,
            name=f"cv_audio_alert_{sound_type.value.lower()}",
        )
        thread.start()
        self._notify_listeners(sound_type, alert_name)

    def _notify_listeners(self, sound_type: SoundType, alert_name: str) -> None:
        """Notify any attached telemetry or UI listeners."""
        for listener in list(self._alert_listeners):
            try:
                listener(sound_type, alert_name)
            except Exception as e:
                logger.debug("Error in audio alert listener: %s", e)

    def _play_file_sync(self, file_path: Path) -> None:
        """Execute system-native audio player synchronously on worker thread."""
        path_str = str(file_path.resolve())

        # 1. macOS: afplay
        if self._platform == "darwin" and self._afplay_bin:
            res = subprocess.run(
                [self._afplay_bin, path_str],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            if res.returncode == 0:
                return

        # 2. Linux: paplay / aplay / pw-play
        if self._platform.startswith("linux"):
            for bin_path in (self._paplay_bin, self._aplay_bin, self._pwplay_bin):
                if bin_path:
                    res = subprocess.run(
                        [bin_path, path_str],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        check=False,
                    )
                    if res.returncode == 0:
                        return

        # 3. Windows: winsound
        if self._platform == "win32":
            try:
                import winsound
                winsound.PlaySound(path_str, winsound.SND_FILENAME)
                return
            except Exception:
                pass

        # 4. ffplay (any OS if installed)
        if self._ffplay_bin:
            res = subprocess.run(
                [self._ffplay_bin, "-nodisp", "-autoexit", "-loglevel", "quiet", path_str],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            if res.returncode == 0:
                return

        # 5. Fallback terminal bell
        self._play_bell_fallback()

    def _play_bell_fallback(self) -> None:
        """Fallback ASCII terminal bell."""
        try:
            sys.stdout.write("\a")
            sys.stdout.flush()
        except Exception:
            pass

    def reset(self) -> None:
        """Clear all cooldown timestamps."""
        with self._lock:
            self._last_alert_times.clear()
            self._last_played_time = 0.0

    def close(self) -> None:
        """Clean up temporary sound files."""
        if self._is_temp_dir and self._cache_dir.exists():
            try:
                shutil.rmtree(self._cache_dir, ignore_errors=True)
            except Exception:
                pass
