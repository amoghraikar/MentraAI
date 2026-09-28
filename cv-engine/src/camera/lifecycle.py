"""
Camera Lifecycle Manager for Mentra Computer Vision Engine.

Implements robust hardware camera acquisition, controlled FPS throttling,
deterministic state machine transitions, clean resource teardown,
and automatic error recovery.
"""

from enum import Enum
import logging
import threading
import time
from typing import Callable, Generator, Optional, Tuple
import cv2
import numpy as np

logger = logging.getLogger("mentra.cv.camera")


class CameraState(str, Enum):
    UNINITIALIZED = "UNINITIALIZED"
    REQUESTING_PERMISSION = "REQUESTING_PERMISSION"
    READY = "READY"
    RUNNING = "RUNNING"
    PAUSED = "PAUSED"
    STOPPING = "STOPPING"
    STOPPED = "STOPPED"
    PERMISSION_DENIED = "PERMISSION_DENIED"
    UNAVAILABLE = "UNAVAILABLE"
    ERROR = "ERROR"


class CameraLifecycleManager:
    """
    Manages local hardware camera capture lifecycle safely.
    Guarantees video resources are strictly released upon stopping or error.
    """

    def __init__(
        self,
        camera_index: int = 0,
        target_fps: float = 8.0,
        max_consecutive_read_errors: int = 5,
    ) -> None:
        self.camera_index = camera_index
        self.target_fps = target_fps
        self.frame_interval = 1.0 / target_fps if target_fps > 0 else 0.125
        self.max_consecutive_read_errors = max_consecutive_read_errors

        self._state = CameraState.UNINITIALIZED
        self._capture: Optional[cv2.VideoCapture] = None
        self._lock = threading.Lock()
        self._last_error: Optional[str] = None
        self._consecutive_errors = 0
        self._last_frame_time = 0.0

    @property
    def state(self) -> CameraState:
        return self._state

    @property
    def last_error(self) -> Optional[str]:
        return self._last_error

    @property
    def is_running(self) -> bool:
        return self._state == CameraState.RUNNING

    def initialize(self) -> bool:
        """Probes camera availability and transitions to READY if hardware is present."""
        with self._lock:
            self._state = CameraState.REQUESTING_PERMISSION
            try:
                cap = cv2.VideoCapture(self.camera_index)
                if not cap.isOpened():
                    self._state = CameraState.UNAVAILABLE
                    self._last_error = f"Camera device at index {self.camera_index} is unavailable."
                    logger.warning(self._last_error)
                    cap.release()
                    return False

                # Warmup grab test
                ret, _ = cap.read()
                cap.release()

                if not ret:
                    self._state = CameraState.UNAVAILABLE
                    self._last_error = "Camera opened but could not read video stream."
                    logger.warning(self._last_error)
                    return False

                self._state = CameraState.READY
                self._last_error = None
                return True
            except PermissionError as pe:
                self._state = CameraState.PERMISSION_DENIED
                self._last_error = f"Camera permission denied: {pe}"
                logger.error(self._last_error)
                return False
            except Exception as e:
                self._state = CameraState.ERROR
                self._last_error = f"Error during camera probe: {e}"
                logger.error(self._last_error)
                return False

    def start(self) -> bool:
        """Opens capture stream and begins running state."""
        with self._lock:
            if self._state == CameraState.RUNNING and self._capture is not None and self._capture.isOpened():
                return True

            if self._state not in (CameraState.READY, CameraState.STOPPED, CameraState.PAUSED, CameraState.UNINITIALIZED):
                if not self.initialize():
                    return False

            try:
                self._capture = cv2.VideoCapture(self.camera_index)
                if not self._capture.isOpened():
                    self._state = CameraState.UNAVAILABLE
                    self._last_error = "Could not open video stream for capture."
                    return False

                self._state = CameraState.RUNNING
                self._consecutive_errors = 0
                self._last_frame_time = time.time()
                logger.info("Camera stream started on device %d at target %.1f FPS", self.camera_index, self.target_fps)
                return True
            except Exception as e:
                self._state = CameraState.ERROR
                self._last_error = f"Failed to start camera: {e}"
                logger.error(self._last_error)
                self._cleanup_capture()
                return False

    def read_frame(self) -> Tuple[bool, Optional[np.ndarray], float]:
        """
        Reads a single frame respecting target FPS throttling.
        Returns: (success: bool, frame: Optional[np.ndarray], timestamp: float)
        """
        with self._lock:
            if self._state != CameraState.RUNNING or self._capture is None or not self._capture.isOpened():
                return False, None, time.time()

            now = time.time()
            elapsed = now - self._last_frame_time
            if elapsed < self.frame_interval:
                # Sleep briefly to maintain controlled frame rate without pinning CPU
                sleep_dur = self.frame_interval - elapsed
                if sleep_dur > 0.001:
                    time.sleep(sleep_dur)
                    now = time.time()

            try:
                ret, frame = self._capture.read()
                self._last_frame_time = now

                if not ret or frame is None or frame.size == 0:
                    self._consecutive_errors += 1
                    logger.warning("Camera read error (%d/%d)", self._consecutive_errors, self.max_consecutive_read_errors)
                    if self._consecutive_errors >= self.max_consecutive_read_errors:
                        self._state = CameraState.ERROR
                        self._last_error = "Excessive consecutive camera read drops."
                        self._cleanup_capture()
                    return False, None, now

                self._consecutive_errors = 0
                return True, frame, now
            except Exception as e:
                self._consecutive_errors += 1
                self._last_error = f"Exception reading frame: {e}"
                logger.error(self._last_error)
                if self._consecutive_errors >= self.max_consecutive_read_errors:
                    self._state = CameraState.ERROR
                    self._cleanup_capture()
                return False, None, now

    def pause(self) -> None:
        """Temporarily pauses frame acquisition without tearing down hardware stream."""
        with self._lock:
            if self._state == CameraState.RUNNING:
                self._state = CameraState.PAUSED
                logger.info("Camera capture paused.")

    def resume(self) -> None:
        """Resumes frame acquisition from paused state."""
        with self._lock:
            if self._state == CameraState.PAUSED:
                self._state = CameraState.RUNNING
                self._last_frame_time = time.time()
                logger.info("Camera capture resumed.")

    def stop(self) -> None:
        """Stops capture and releases all video hardware resources."""
        with self._lock:
            if self._state in (CameraState.STOPPED, CameraState.UNINITIALIZED):
                return
            self._state = CameraState.STOPPING
            self._cleanup_capture()
            self._state = CameraState.STOPPED
            logger.info("Camera stream cleanly stopped and resources released.")

    def _cleanup_capture(self) -> None:
        if self._capture is not None:
            try:
                if self._capture.isOpened():
                    self._capture.release()
            except Exception as e:
                logger.debug("Error releasing camera capture: %s", e)
            finally:
                self._capture = None

    def __enter__(self) -> "CameraLifecycleManager":
        self.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        self.stop()
