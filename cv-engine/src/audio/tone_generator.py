"""Tone and Audio Waveform Generator.

Generates smooth, pleasant audio alerts using standard Python library
(wave, struct, math) without external C or binary audio dependencies.
"""

from enum import Enum
import io
import math
from pathlib import Path
import struct
import tempfile
from typing import Optional, Union
import wave


class SoundType(str, Enum):
    DISTRACTION = "DISTRACTION"
    DROWSINESS = "DROWSINESS"
    BEEP = "BEEP"


class ToneGenerator:
    """Synthesizes PCM WAV audio waveforms in memory or to disk with envelope smoothing."""

    DEFAULT_SAMPLE_RATE = 44100

    @staticmethod
    def generate_sine_wave_pcm(
        frequency: float,
        duration_seconds: float,
        sample_rate: int = DEFAULT_SAMPLE_RATE,
        volume: float = 0.5,
        attack_ms: float = 15.0,
        release_ms: float = 25.0,
    ) -> bytes:
        """Generate 16-bit mono PCM bytes for a pure sine tone with linear attack/release."""
        volume = max(0.0, min(1.0, volume))
        num_samples = int(sample_rate * duration_seconds)
        attack_samples = int(sample_rate * (attack_ms / 1000.0))
        release_samples = int(sample_rate * (release_ms / 1000.0))

        frames = bytearray()
        max_amplitude = 32767.0 * volume

        for i in range(num_samples):
            t = float(i) / sample_rate

            # Envelope calculation to eliminate clicks/pops
            if attack_samples > 0 and i < attack_samples:
                envelope = float(i) / attack_samples
            elif release_samples > 0 and i >= (num_samples - release_samples):
                envelope = float(num_samples - i) / release_samples
            else:
                envelope = 1.0

            sample_val = int(max_amplitude * envelope * math.sin(2.0 * math.pi * frequency * t))
            # Clamp to 16-bit signed range
            sample_val = max(-32768, min(32767, sample_val))
            frames.extend(struct.pack("<h", sample_val))

        return bytes(frames)

    @classmethod
    def generate_wav_bytes(
        cls,
        pcm_data: bytes,
        sample_rate: int = DEFAULT_SAMPLE_RATE,
    ) -> bytes:
        """Package 16-bit mono PCM samples into a standard RIFF/WAV container."""
        buffer = io.BytesIO()
        with wave.open(buffer, "wb") as wf:
            wf.setnchannels(1)  # Mono
            wf.setsampwidth(2)  # 16-bit
            wf.setframerate(sample_rate)
            wf.writeframes(pcm_data)
        return buffer.getvalue()

    @classmethod
    def generate_distraction_tone(
        cls,
        volume: float = 0.45,
        sample_rate: int = DEFAULT_SAMPLE_RATE,
    ) -> bytes:
        """Pleasant two-tone ascending chime (E5: 659.25Hz -> A5: 880.0Hz).

        Soft, non-jarring reminder to gently nudge attention back to the screen.
        """
        # Tone 1: E5 (659.25 Hz) for 90ms
        tone1 = cls.generate_sine_wave_pcm(
            frequency=659.25,
            duration_seconds=0.09,
            sample_rate=sample_rate,
            volume=volume * 0.9,
            attack_ms=10.0,
            release_ms=15.0,
        )
        # Short 20ms pause
        pause_samples = int(sample_rate * 0.02)
        silence = bytes(pause_samples * 2)

        # Tone 2: A5 (880.0 Hz) for 140ms
        tone2 = cls.generate_sine_wave_pcm(
            frequency=880.0,
            duration_seconds=0.14,
            sample_rate=sample_rate,
            volume=volume,
            attack_ms=10.0,
            release_ms=30.0,
        )

        combined_pcm = tone1 + silence + tone2
        return cls.generate_wav_bytes(combined_pcm, sample_rate=sample_rate)

    @classmethod
    def generate_drowsiness_tone(
        cls,
        volume: float = 0.65,
        sample_rate: int = DEFAULT_SAMPLE_RATE,
    ) -> bytes:
        """Urgent, clear two-pulse wake-up alert (C5: 523.25Hz -> G5: 783.99Hz).

        Designed to firmly alert and re-energize a student with drooping eyelids.
        """
        # Pulse 1: 523.25 Hz for 130ms
        pulse1 = cls.generate_sine_wave_pcm(
            frequency=523.25,
            duration_seconds=0.13,
            sample_rate=sample_rate,
            volume=volume * 0.95,
            attack_ms=8.0,
            release_ms=15.0,
        )
        # 40ms pause
        pause_samples = int(sample_rate * 0.04)
        silence = bytes(pause_samples * 2)

        # Pulse 2: 783.99 Hz for 180ms
        pulse2 = cls.generate_sine_wave_pcm(
            frequency=783.99,
            duration_seconds=0.18,
            sample_rate=sample_rate,
            volume=volume,
            attack_ms=8.0,
            release_ms=25.0,
        )

        combined_pcm = pulse1 + silence + pulse2
        return cls.generate_wav_bytes(combined_pcm, sample_rate=sample_rate)

    @classmethod
    def generate_simple_beep(
        cls,
        frequency: float = 880.0,
        duration_seconds: float = 0.18,
        volume: float = 0.5,
        sample_rate: int = DEFAULT_SAMPLE_RATE,
    ) -> bytes:
        """Generate a single clean sine beep."""
        pcm = cls.generate_sine_wave_pcm(
            frequency=frequency,
            duration_seconds=duration_seconds,
            sample_rate=sample_rate,
            volume=volume,
        )
        return cls.generate_wav_bytes(pcm, sample_rate=sample_rate)

    @classmethod
    def save_wav_file(cls, wav_bytes: bytes, destination_path: Union[str, Path]) -> Path:
        """Save raw WAV bytes to a file on disk."""
        path = Path(destination_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(wav_bytes)
        return path
