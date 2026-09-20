"""Backend Computer Vision Service bridge to the local cv-engine."""

from dataclasses import asdict
import logging
from pathlib import Path
import sys
import threading
from typing import Any, Dict, Optional

# Dynamically ensure cv-engine and its virtualenv packages are importable
CV_ENGINE_DIR = Path(__file__).resolve().parents[3] / "cv-engine"
CV_SITE_PACKAGES = CV_ENGINE_DIR / ".venv" / "lib" / "python3.11" / "site-packages"

if CV_SITE_PACKAGES.exists() and str(CV_SITE_PACKAGES) not in sys.path:
    sys.path.append(str(CV_SITE_PACKAGES))
if CV_ENGINE_DIR.exists() and str(CV_ENGINE_DIR) not in sys.path:
    sys.path.insert(0, str(CV_ENGINE_DIR))

try:
    from src import CVBaseline, CvEngine, FrameDecoder
except Exception as e:
    logging.getLogger("mentra.cv").error("Failed to import CvEngine: %s", e)
    CvEngine = None
    CVBaseline = None
    FrameDecoder = None

logger = logging.getLogger("mentra.cv")


class CvService:
    """Thread-safe singleton service wrapping the local Computer Vision Engine."""

    _instance = None
    _lock = threading.Lock()

    def __init__(self) -> None:
        self.engine = None
        if CvEngine is not None:
            try:
                self.engine = CvEngine(enable_phone_detection=True)
                logger.info("Local CvEngine initialized successfully in CvService.")
            except Exception as e:
                logger.error("Error initializing CvEngine: %s", e)
                try:
                    # Fallback without phone detector if model loading failed
                    self.engine = CvEngine(enable_phone_detection=False)
                    logger.info("CvEngine initialized without phone detector fallback.")
                except Exception as ex:
                    logger.error("Failed fallback CvEngine init: %s", ex)
                    self.engine = None

    @classmethod
    def get_instance(cls) -> "CvService":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = cls()
        return cls._instance

    def process_base64_frame(
        self,
        b64_image: str,
        timestamp: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Decode base64 image and process through master CvEngine."""
        if not self.engine or FrameDecoder is None:
            raise RuntimeError("Computer vision engine is unavailable on this system.")

        frame = FrameDecoder.decode_base64(b64_image)
        result = self.engine.process_frame(frame, timestamp=timestamp)
        return result.to_dict()

    def start_calibration(self) -> None:
        """Start calibration session."""
        if self.engine:
            self.engine.start_calibration()

    def process_calibration_frame(
        self,
        b64_image: str,
        timestamp: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Decode base64 frame and add to calibration accumulator."""
        if not self.engine or FrameDecoder is None:
            raise RuntimeError("Computer vision engine is unavailable.")
        frame = FrameDecoder.decode_base64(b64_image)
        return self.engine.process_calibration_frame(frame, timestamp=timestamp)

    def finish_calibration(self) -> Optional[Dict[str, Any]]:
        """Finalize calibration and return baseline dict."""
        if not self.engine:
            return None
        baseline = self.engine.finish_calibration()
        return baseline.to_dict() if baseline else None

    def get_baseline(self) -> Optional[Dict[str, Any]]:
        """Get currently active baseline."""
        if not self.engine or not self.engine.current_baseline:
            return None
        return self.engine.current_baseline.to_dict()

    def set_baseline(self, baseline_data: Dict[str, Any]) -> None:
        """Set baseline from dictionary."""
        if self.engine and CVBaseline:
            baseline = CVBaseline.from_dict(baseline_data)
            self.engine.set_baseline(baseline)

    def evaluate_quality(self, b64_image: str) -> Dict[str, Any]:
        """Evaluate camera quality without processing focus behaviors."""
        if not self.engine or FrameDecoder is None:
            raise RuntimeError("Computer vision engine is unavailable.")
        frame = FrameDecoder.decode_base64(b64_image)
        res = self.engine.evaluate_quality(frame)
        return res.to_dict()

    def pause_session(self) -> None:
        """Pause focus monitoring accumulation."""
        if self.engine:
            self.engine.pause()

    def resume_session(self) -> None:
        """Resume focus monitoring accumulation."""
        if self.engine:
            self.engine.resume()

    def reset_session(self) -> None:
        """Reset temporal smoothing and metrics counters."""
        if self.engine:
            self.engine.reset()

    def get_status(self) -> Dict[str, Any]:
        """Return engine operational status."""
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
        }


cv_service = CvService.get_instance()
