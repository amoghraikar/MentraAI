from typing import Any, Dict, List, Optional, Tuple
from pydantic import BaseModel, Field


class CvFrameRequest(BaseModel):
    image_base64: str = Field(..., description="Base64 encoded JPEG/PNG frame from webcam")
    session_id: Optional[str] = Field(None, description="Optional study session ID")
    timestamp: Optional[float] = Field(None, description="Client frame timestamp")


class CvBoundingBox(BaseModel):
    x: float
    y: float
    width: float
    height: float


class CvAlert(BaseModel):
    id: str
    type: str
    timestamp: float
    message: str
    severity: str


class CvSessionMetrics(BaseModel):
    total_observed_seconds: float = 0.0
    focused_seconds: float = 0.0
    away_seconds: float = 0.0
    looking_away_seconds: float = 0.0
    looking_down_seconds: float = 0.0
    drowsy_seconds: float = 0.0
    phone_seconds: float = 0.0
    focus_score: int = 100
    distraction_count: int = 0
    drowsiness_count: int = 0
    phone_count: int = 0


class CvFrameResponse(BaseModel):
    timestamp: float
    face_detected: bool
    face_confidence: float
    bounding_box: Optional[CvBoundingBox] = None
    landmarks: List[Tuple[float, float]] = []  # 2D key anchors: [left_eye, right_eye, nose, mouth]
    yaw: float
    pitch: float
    roll: float
    orientation: str
    ear: float
    left_ear: float
    right_ear: float
    eyes_closed: bool
    is_drowsy: bool
    phone_detected: bool
    phone_confidence: float
    phone_bounding_box: Optional[List[float]] = None
    focus_state: str
    alert: Optional[CvAlert] = None
    session_metrics: CvSessionMetrics
    fps: float
    latency_ms: float


class CvStatusResponse(BaseModel):
    status: str
    engine_ready: bool
    face_mesh_active: bool
    head_pose_active: bool
    ear_active: bool
    phone_detection_active: bool
    supported_classes: List[str]
