"""Frame Ingestion & Camera Utilities Module."""

import base64
import time
from typing import Optional, Tuple
import cv2
import numpy as np

from .quality import CameraQualityEvaluator, CameraQualityResult, CameraQualityStatus


class FrameDecoder:
    """Decodes incoming raw bytes or Base64 image payloads into OpenCV BGR numpy arrays."""

    @staticmethod
    def decode_base64(data_uri_or_base64: str) -> Optional[np.ndarray]:
        """Decode base64 string (with or without data:image/jpeg;base64, prefix) to BGR frame."""
        if not data_uri_or_base64:
            return None

        try:
            if "," in data_uri_or_base64:
                _, b64_str = data_uri_or_base64.split(",", 1)
            else:
                b64_str = data_uri_or_base64

            raw_bytes = base64.b64decode(b64_str)
            nparr = np.frombuffer(raw_bytes, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            return frame
        except Exception:
            return None

    @staticmethod
    def decode_bytes(raw_bytes: bytes) -> Optional[np.ndarray]:
        """Decode raw JPEG/PNG byte buffer to BGR frame."""
        if not raw_bytes:
            return None
        try:
            nparr = np.frombuffer(raw_bytes, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            return frame
        except Exception:
            return None


class FpsTracker:
    """Measures actual processing frames per second."""

    def __init__(self, window_size: int = 20) -> None:
        self.window_size = window_size
        self._timestamps: list = []

    def tick(self) -> float:
        """Record frame timestamp and return measured FPS."""
        now = time.time()
        self._timestamps.append(now)
        if len(self._timestamps) > self.window_size:
            self._timestamps.pop(0)

        if len(self._timestamps) < 2:
            return 0.0

        elapsed = self._timestamps[-1] - self._timestamps[0]
        if elapsed <= 0:
            return 0.0

        return round((len(self._timestamps) - 1) / elapsed, 1)
