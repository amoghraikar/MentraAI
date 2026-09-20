"""Real Local Object and Phone Detection Module using Ultralytics YOLOv8."""

from dataclasses import dataclass
import logging
from typing import List, Optional
import numpy as np

logger = logging.getLogger(__name__)


@dataclass
class PhoneResult:
    detected: bool
    confidence: float
    bounding_box: Optional[List[float]] = None  # [x1, y1, x2, y2] normalized
    available: bool = True


class PhoneDetector:
    """Detects cell phones locally on CPU/Metal using YOLOv8n without external APIs."""

    CELL_PHONE_CLASS_ID = 67  # COCO dataset class index for cell phone

    def __init__(self, model_path: str = "yolov8n.pt", min_confidence: float = 0.40) -> None:
        self.min_confidence = min_confidence
        self.model = None
        self.available = False

        from pathlib import Path

        # Check local file paths
        candidate_paths = [
            Path(model_path),
            Path(__file__).resolve().parent.parent.parent / model_path,
            Path(__file__).resolve().parent.parent / model_path,
            Path(__file__).resolve().parents[3] / model_path,
        ]
        resolved_path = None
        for p in candidate_paths:
            if p.is_file():
                resolved_path = str(p)
                break

        if not resolved_path:
            logger.info("Local YOLO weights not found at '%s'. Phone detection marked unavailable.", model_path)
            self.available = False
            return

        try:
            from ultralytics import YOLO

            self.model = YOLO(resolved_path)
            self.available = True
            logger.info("YOLOv8 Phone Detector initialized successfully with %s.", resolved_path)
        except Exception as e:
            logger.warning("Failed to initialize YOLO model for phone detection: %s", e)
            self.available = False

    def process(self, frame: np.ndarray) -> PhoneResult:
        """Process a BGR frame and return real cell phone detection status."""
        if not self.available or self.model is None or frame is None or frame.size == 0:
            return PhoneResult(detected=False, confidence=0.0, available=self.available)

        h, w = frame.shape[:2]
        try:
            # Predict only for class 67 (cell phone)
            results = self.model.predict(
                frame,
                classes=[self.CELL_PHONE_CLASS_ID],
                conf=self.min_confidence,
                verbose=False,
            )

            if not results or len(results) == 0 or len(results[0].boxes) == 0:
                return PhoneResult(detected=False, confidence=0.0, available=True)

            boxes = results[0].boxes
            best_conf = 0.0
            best_bbox = None

            for box in boxes:
                conf = float(box.conf[0])
                if conf > best_conf:
                    best_conf = conf
                    xyxy = box.xyxy[0].tolist()
                    # Normalize bounding box (0.0 to 1.0)
                    best_bbox = [
                        round(xyxy[0] / w, 4),
                        round(xyxy[1] / h, 4),
                        round(xyxy[2] / w, 4),
                        round(xyxy[3] / h, 4),
                    ]

            return PhoneResult(
                detected=True,
                confidence=round(best_conf, 3),
                bounding_box=best_bbox,
                available=True,
            )
        except Exception as e:
            logger.debug("Error during phone inference: %s", e)
            return PhoneResult(detected=False, confidence=0.0, available=self.available)
