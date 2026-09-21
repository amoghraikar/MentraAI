"""Backend Computer Vision Service bridge to the local cv-engine.

Reliability contract
--------------------
The CV engine is a stateful, non-thread-safe object graph (MediaPipe + YOLO).
Historically the bridge had three failure modes that made CV "work, then
randomly stop working":

1. A broken engine was cached forever. If the first ``CvEngine()`` construction
   failed, ``cv_service.engine`` stayed ``None`` for the whole process and every
   ``/cv/*`` call returned 503 until a manual restart.
2. Only ``process_base64_frame`` took the frame lock. Calibration and quality
   calls entered the same detectors concurrently, corrupting detector state.
3. Frame requests blocked indefinitely on a busy engine, so an overloaded
   backend looked "unresponsive" instead of degrading gracefully.

This module fixes all three: the engine is (re)created lazily on demand, every
engine touch is serialized through one lock, frame processing is bounded and
falls back to the last good result when the engine is saturated, and the engine
is reset (then reinitialized) after consecutive failures.
"""

import logging
from pathlib import Path
import sys
import threading
import time
from typing import Any, Dict, Optional

# --- CV Engine Discovery ---
# The cv-engine source is at <repo>/cv-engine/src.
# Its Python dependencies (opencv, mediapipe, ultralytics) are installed in the
# backend's own virtualenv (backend/.venv), so we only need to add the
# cv-engine *source* root to sys.path — the interpreter already has the packages.
CV_ENGINE_DIR = Path(__file__).resolve().parents[3] / "cv-engine"

# Also try legacy cv-engine venv location as a fallback (in case they exist)
_LEGACY_VENV_CANDIDATES = [
    CV_ENGINE_DIR / ".venv" / "lib" / "python3.12" / "site-packages",
    CV_ENGINE_DIR / ".venv" / "lib" / "python3.11" / "site-packages",
    CV_ENGINE_DIR / ".venv" / "lib" / "python3.10" / "site-packages",
]
for _candidate in _LEGACY_VENV_CANDIDATES:
    if _candidate.exists() and str(_candidate) not in sys.path:
        sys.path.append(str(_candidate))
        break

if CV_ENGINE_DIR.exists() and str(CV_ENGINE_DIR) not in sys.path:
    sys.path.insert(0, str(CV_ENGINE_DIR))

logger = logging.getLogger("mentra.cv")

try:
    from src import CVBaseline, CvEngine, FrameDecoder
    _CV_IMPORT_ERROR: Optional[str] = None
except Exception as e:
    logger.error("Failed to import CvEngine from %s: %s", CV_ENGINE_DIR, e)
    CvEngine = None  # type: ignore[assignment, misc]
    CVBaseline = None  # type: ignore[assignment, misc]
    FrameDecoder = None  # type: ignore[assignment, misc]
    _CV_IMPORT_ERROR = str(e)


def cv_engine_available() -> bool:
    """True when the cv-engine package imported successfully at process start."""
    return CvEngine is not None


class CvService:
    """Thread-safe singleton service wrapping the local Computer Vision Engine.

    The engine is created lazily and re-created automatically if it ever fails,
    so transient dependency/model problems can never permanently disable CV for
    the lifetime of the process.
    """

    _instance = None
    _lock = threading.Lock()         # guards singleton creation
    _frame_lock = threading.Lock()   # serializes ALL engine access

    # Re-initialization policy
    _MAX_CONSECUTIVE_FAILURES = 3
    _REINIT_COOLDOWN_SECONDS = 5.0
    _INIT_TIMEOUT_SECONDS = 60.0

    # When the engine is saturated, wait this long for a slot before serving the
    # last known-good result instead of queueing more work.
    _FRAME_ACQUIRE_TIMEOUT_SECONDS = 2.0

    def __init__(self) -> None:
        self.engine = None
        self._engine_lock = threading.Lock()
        self._consecutive_failures = 0
        self._last_error: Optional[str] = None
        self._last_failed_init_at: float = 0.0
        self._last_init_duration_ms: float = 0.0
        self._reinitializations = 0
        self._phone_detection_enabled = True
        self._started_at = time.time()
        self._last_result: Optional[Dict[str, Any]] = None
        self._last_calibration_result: Optional[Dict[str, Any]] = None

        # Eager first attempt so obvious breakage is logged at startup, but a
        # failure here is recoverable rather than permanent.
        self._ensure_engine(force=True)

    @classmethod
    def get_instance(cls) -> "CvService":
        """Return the process-wide singleton, creating it on first use."""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = cls()
        return cls._instance

    # ------------------------------------------------------------------
    # Engine lifecycle
    # ------------------------------------------------------------------
    def _ensure_engine(self, force: bool = False) -> bool:
        """Ensure a usable engine exists, creating it on demand.

        Returns True when ``self.engine`` is usable. Never raises.
        """
        if self.engine is not None and not force:
            return True

        with self._engine_lock:
            if self.engine is not None and not force:
                return True

            if CvEngine is None:
                self._last_error = _CV_IMPORT_ERROR or "cv-engine package could not be imported"
                return False

            # Throttle only after a *failed* build so a working engine that later
            # dies can be rebuilt immediately.
            now = time.monotonic()
            if (
                not force
                and self._last_failed_init_at > 0
                and (now - self._last_failed_init_at) < self._REINIT_COOLDOWN_SECONDS
            ):
                return False

            started = time.time()
            engine = None
            phone_enabled = True
            try:
                engine = CvEngine(enable_phone_detection=True)
            except Exception as e:
                logger.error("Error initializing CvEngine (phone=True): %s", e)
                try:
                    # Fallback: init without the YOLO phone detector
                    engine = CvEngine(enable_phone_detection=False)
                    phone_enabled = False
                    logger.warning("CvEngine initialized without phone detector (fallback).")
                except Exception as ex:
                    logger.error("Failed fallback CvEngine init: %s", ex)
                    engine = None

            self._last_init_duration_ms = (time.time() - started) * 1000.0

            if engine is None:
                self.engine = None
                self._last_failed_init_at = time.monotonic()
                self._last_error = (
                    "Computer vision engine could not be initialized. "
                    "Ensure cv-engine dependencies are installed in the backend virtualenv."
                )
                return False

            if self.engine is not None:
                self._reinitializations += 1
            self.engine = engine
            self._phone_detection_enabled = phone_enabled
            self._consecutive_failures = 0
            self._last_error = None
            self._last_failed_init_at = 0.0
            self._last_result = None
            self._last_calibration_result = None
            logger.info(
                "CvService engine ready in %.0fms (phone_detection=%s, reinitializations=%d).",
                self._last_init_duration_ms,
                phone_enabled,
                self._reinitializations,
            )
            return True

    def _require_engine(self):
        """Return a usable engine or raise RuntimeError with a clear message."""
        if not self._ensure_engine():
            raise RuntimeError(self._unavailable_reason())
        return self.engine

    def _unavailable_reason(self) -> str:
        if CvEngine is None:
            return (
                "Computer vision engine is unavailable on this system. "
                f"cv-engine import failed: {_CV_IMPORT_ERROR or 'unknown error'}. "
                "Ensure cv-engine dependencies are installed in the backend virtualenv."
            )
        return (
            "Computer vision engine is temporarily unavailable"
            + (f": {self._last_error}" if self._last_error else ".")
        )

    def _register_failure(self, exc: Exception) -> None:
        """Reset the engine after a failure and reinitialize once it stays broken."""
        self._last_error = f"{type(exc).__name__}: {exc}"
        self._consecutive_failures += 1
        logger.warning(
            "CV engine call failed (%d consecutive): %s",
            self._consecutive_failures,
            exc,
        )

        # Cheap first: clear temporal/detector accumulators before rebuilding.
        try:
            if self.engine is not None:
                self.engine.reset()
        except Exception as reset_exc:
            logger.debug("CV engine soft reset failed: %s", reset_exc)

        if self._consecutive_failures >= self._MAX_CONSECUTIVE_FAILURES:
            logger.error(
                "CV engine unhealthy after %d consecutive failures — rebuilding engine.",
                self._consecutive_failures,
            )
            with self._engine_lock:
                self.engine = None
            self._consecutive_failures = 0
            # force=True is safe here: failures are rare and rebuilding restores service.
            self._ensure_engine(force=True)

    # ------------------------------------------------------------------
    # Frame processing
    # ------------------------------------------------------------------
    def process_base64_frame(
        self,
        b64_image: str,
        timestamp: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Decode a base64 image and process it through the master CvEngine.

        Thread-safe. When the engine is saturated the last known-good result is
        returned (marked ``busy``) rather than blocking the request queue, which
        keeps the live feed responsive under load.
        """
        if FrameDecoder is None:
            raise RuntimeError(self._unavailable_reason())

        engine = self._require_engine()
        frame = FrameDecoder.decode_base64(b64_image)

        acquired = self.__class__._frame_lock.acquire(
            timeout=self._FRAME_ACQUIRE_TIMEOUT_SECONDS
        )
        if not acquired:
            if self._last_result is not None:
                busy_result = dict(self._last_result)
                busy_result["busy"] = True
                return busy_result
            raise RuntimeError(
                "Computer vision engine is busy processing frames. "
                "Reduce the client frame rate and try again."
            )

        try:
            result = engine.process_frame(frame, timestamp=timestamp)
            payload = result.to_dict()
            self._last_result = payload
            self._consecutive_failures = 0
            return payload
        except Exception as e:
            self._register_failure(e)
            raise
        finally:
            self.__class__._frame_lock.release()

    # ------------------------------------------------------------------
    # Calibration
    # ------------------------------------------------------------------
    def start_calibration(self) -> None:
        """Start a calibration session."""
        engine = self._require_engine()
        with self.__class__._frame_lock:
            engine.start_calibration()

    def process_calibration_frame(
        self,
        b64_image: str,
        timestamp: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Decode a base64 frame and add it to the calibration accumulator.

        Serialized against ``process_base64_frame`` so the shared face detector
        is never entered concurrently.
        """
        if FrameDecoder is None:
            raise RuntimeError(self._unavailable_reason())

        engine = self._require_engine()
        frame = FrameDecoder.decode_base64(b64_image)

        acquired = self.__class__._frame_lock.acquire(timeout=1.0)
        if not acquired:
            # Skipping a single 120ms calibration sample is harmless.
            if self._last_calibration_result is not None:
                return dict(self._last_calibration_result)
            return {
                "active": True,
                "progress": 0.0,
                "is_complete": False,
                "face_detected": False,
                "quality": "UNKNOWN",
                "message": "Calibration sampling is busy; hold still.",
            }

        try:
            result = engine.process_calibration_frame(frame, timestamp=timestamp)
            self._last_calibration_result = result
            self._consecutive_failures = 0
            return result
        except Exception as e:
            self._register_failure(e)
            raise
        finally:
            self.__class__._frame_lock.release()

    def finish_calibration(self) -> Optional[Dict[str, Any]]:
        """Finalize calibration and return the baseline dict."""
        engine = self._require_engine()
        with self.__class__._frame_lock:
            baseline = engine.finish_calibration()
            return baseline.to_dict() if baseline else None

    def get_baseline(self) -> Optional[Dict[str, Any]]:
        """Get the currently active baseline."""
        if self.engine is None or not self.engine.current_baseline:
            return None
        with self.__class__._frame_lock:
            if not self.engine.current_baseline:
                return None
            return self.engine.current_baseline.to_dict()

    def set_baseline(self, baseline_data: Dict[str, Any]) -> None:
        """Restore a previously established baseline."""
        engine = self._require_engine()
        if CVBaseline is None:
            raise RuntimeError(self._unavailable_reason())
        baseline = CVBaseline.from_dict(baseline_data)
        with self.__class__._frame_lock:
            engine.set_baseline(baseline)

    def evaluate_quality(self, b64_image: str) -> Dict[str, Any]:
        """Evaluate camera quality without processing focus behaviors."""
        if FrameDecoder is None:
            raise RuntimeError(self._unavailable_reason())

        engine = self._require_engine()
        frame = FrameDecoder.decode_base64(b64_image)

        with self.__class__._frame_lock:
            res = engine.evaluate_quality(frame)
            return res.to_dict()

    # ------------------------------------------------------------------
    # Session control
    # ------------------------------------------------------------------
    def pause_session(self) -> None:
        """Pause focus monitoring accumulation."""
        if self.engine is None:
            return
        with self.__class__._frame_lock:
            self.engine.pause()

    def resume_session(self) -> None:
        """Resume focus monitoring accumulation."""
        if self.engine is None:
            return
        with self.__class__._frame_lock:
            self.engine.resume()

    def reset_session(self) -> None:
        """Reset temporal smoothing and metrics counters."""
        if self.engine is None:
            return
        with self.__class__._frame_lock:
            self.engine.reset()

    # ------------------------------------------------------------------
    # Status
    # ------------------------------------------------------------------
    def get_status(self) -> Dict[str, Any]:
        """Return engine operational status, including recovery diagnostics."""
        # Only attempt a rebuild if we don't already have a working engine, so
        # this endpoint stays fast when polled by the client.
        if self.engine is None:
            self._ensure_engine()

        ready = self.engine is not None
        phone_active = (
            self.engine.phone_detector is not None and self.engine.phone_detector.available
            if ready
            else False
        )
        return {
            "status": "ready" if ready else "unavailable",
            "engine_ready": ready,
            "face_mesh_active": ready,
            "head_pose_active": ready,
            "ear_active": ready,
            "phone_detection_active": phone_active,
            "supported_classes": ["face", "eyes_ear", "head_pose", "cell_phone"],
            "engine_reinitializations": self._reinitializations,
            "last_error": self._last_error,
            "uptime_seconds": round(time.time() - self._started_at, 1),
        }

    @classmethod
    def reset_singleton(cls) -> None:
        """Drop the cached singleton. Test/repair hook."""
        with cls._lock:
            cls._instance = None


cv_service = CvService.get_instance()
