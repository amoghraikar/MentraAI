"""REST API endpoints for live Computer Vision, Calibration, Quality, and Focus Telemetry."""

import logging
from typing import Any, Dict, Optional
from fastapi import APIRouter, HTTPException, status

from app.schemas.cv import (
    CvBaselineModel,
    CvCalibrationFrameRequest,
    CvCalibrationFrameResponse,
    CvCalibrationStartResponse,
    CvFrameRequest,
    CvFrameResponse,
    CvQualityResponse,
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


@router.post(
    "/calibrate/start",
    response_model=CvCalibrationStartResponse,
    summary="Start a 3-second camera calibration session",
)
def start_calibration() -> CvCalibrationStartResponse:
    """Initiate collection of resting posture and eye measurements."""
    cv_service.start_calibration()
    return CvCalibrationStartResponse(
        status="active",
        message="Calibration started. Sit naturally and look at the screen for 3 seconds.",
    )


@router.post(
    "/calibrate/frame",
    response_model=CvCalibrationFrameResponse,
    summary="Feed a frame into calibration session",
)
def process_calibration_frame(payload: CvCalibrationFrameRequest) -> CvCalibrationFrameResponse:
    """Collect calibration sample from webcam frame."""
    try:
        res = cv_service.process_calibration_frame(
            b64_image=payload.image_base64,
            timestamp=payload.timestamp,
        )
        return CvCalibrationFrameResponse(**res)
    except Exception as e:
        logger.error("Error during calibration frame processing: %s", e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Calibration frame failed: {e}",
        )


@router.post(
    "/calibrate/finish",
    response_model=Optional[CvBaselineModel],
    summary="Finalize calibration and establish baseline",
)
def finish_calibration() -> Optional[CvBaselineModel]:
    """Calculate and lock in personal baseline measurements."""
    baseline = cv_service.finish_calibration()
    if baseline is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Calibration failed: insufficient valid face samples. Ensure face is clearly visible.",
        )
    return CvBaselineModel(**baseline)


@router.get(
    "/calibrate/baseline",
    response_model=Optional[CvBaselineModel],
    summary="Get active session baseline",
)
def get_current_baseline() -> Optional[CvBaselineModel]:
    """Retrieve active calibrated baseline if present."""
    baseline = cv_service.get_baseline()
    if not baseline:
        return None
    return CvBaselineModel(**baseline)


@router.post(
    "/calibrate/baseline",
    response_model=CvBaselineModel,
    summary="Set or restore an established baseline",
)
def set_current_baseline(payload: CvBaselineModel) -> CvBaselineModel:
    """Manually apply an established baseline."""
    cv_service.set_baseline(payload.dict())
    return payload


@router.post(
    "/quality",
    response_model=CvQualityResponse,
    summary="Check camera conditions (lighting, distance, visibility)",
)
def evaluate_camera_quality(payload: CvCalibrationFrameRequest) -> CvQualityResponse:
    """Evaluate camera quality without changing focus state."""
    try:
        res = cv_service.evaluate_quality(payload.image_base64)
        return CvQualityResponse(**res)
    except Exception as e:
        logger.error("Error checking camera quality: %s", e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Quality check failed: {e}",
        )


@router.post("/pause", summary="Pause study session CV metrics accumulation")
def pause_cv_monitoring() -> dict:
    """Pause metrics timer when study session is paused."""
    cv_service.pause_session()
    return {"message": "CV monitoring paused."}


@router.post("/resume", summary="Resume study session CV metrics accumulation")
def resume_cv_monitoring() -> dict:
    """Resume metrics timer when study session resumes."""
    cv_service.resume_session()
    return {"message": "CV monitoring resumed."}


@router.post("/reset", summary="Reset CV temporal tracking and metrics")
def reset_cv_session() -> dict:
    """Reset temporal debouncing buffers, drowsiness state, and cumulative metrics."""
    cv_service.reset_session()
    return {"message": "CV tracking session reset successfully."}
