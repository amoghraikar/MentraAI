"""REST API endpoints for live Computer Vision and Focus Telemetry."""

import logging
from fastapi import APIRouter, HTTPException, status

from app.schemas.cv import (
    CvFrameRequest,
    CvFrameResponse,
    CvStatusResponse,
)
from app.services.cv_service import cv_service

logger = logging.getLogger("mentra.cv.endpoint")

router = APIRouter()


@router.get("/status", response_model=CvStatusResponse, summary="Get CV Engine Health and Status")
def get_cv_status() -> CvStatusResponse:
    """Check availability of local MediaPipe and YOLO models."""
    return CvStatusResponse(**cv_service.get_status())


@router.post(
    "/process-frame",
    response_model=CvFrameResponse,
    summary="Process live camera frame locally",
)
def process_frame(payload: CvFrameRequest) -> CvFrameResponse:
    """Ingest a live webcam frame, perform face/ear/head-pose/phone inference,

    and return verified behavioral focus observations.
    """
    try:
        res = cv_service.process_base64_frame(
            b64_image=payload.image_base64,
            timestamp=payload.timestamp,
        )
        return CvFrameResponse(**res)
    except RuntimeError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(e),
        )
    except Exception as e:
        logger.error("Error processing video frame: %s", e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Frame processing failed: {e}",
        )


@router.post("/reset", summary="Reset CV temporal tracking and metrics")
def reset_cv_session() -> dict:
    """Reset temporal debouncing buffers, drowsiness state, and cumulative metrics."""
    cv_service.reset_session()
    return {"message": "CV tracking session reset successfully."}
