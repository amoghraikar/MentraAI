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
    focused_duration: float = 0.0
    looking_away_duration: float = 0.0
    eyes_closed_duration: float = 0.0
    possible_drowsiness_duration: float = 0.0
    phone_detected_duration: float = 0.0
    face_not_detected_duration: float = 0.0
    unknown_duration: float = 0.0

    number_of_distraction_events: int = 0
    number_of_looking_away_events: int = 0
    number_of_eye_closure_events: int = 0
    number_of_phone_events: int = 0

    longest_focused_period: float = 0.0
    longest_distraction_period: float = 0.0

    focus_score: Optional[int] = None

    # Backward compatibility aliases
    focused_seconds: float = 0.0
    away_seconds: float = 0.0
    looking_away_seconds: float = 0.0
    looking_down_seconds: float = 0.0
    drowsy_seconds: float = 0.0
    phone_seconds: float = 0.0
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
    yaw_deviation: float = 0.0
    pitch_deviation: float = 0.0
    roll_deviation: float = 0.0
    orientation: str
    ear: float
    left_ear: float
    right_ear: float
    eyes_closed: bool
    eye_state: str = "UNKNOWN"
    is_drowsy: bool
    phone_detected: bool
    phone_confidence: float
    phone_bounding_box: Optional[List[float]] = None
    phone_available: bool = False
    focus_state: str
    confidence_level: str = "UNKNOWN"
    camera_quality: Optional[Dict[str, Any]] = None
    alert: Optional[CvAlert] = None
    session_metrics: CvSessionMetrics
    fps: float
    latency_ms: float
    baseline_active: bool = False


class CvStatusResponse(BaseModel):
    status: str
    engine_ready: bool
    face_mesh_active: bool
    head_pose_active: bool
    ear_active: bool
    phone_detection_active: bool
    supported_classes: List[str]


class CvCalibrationStartResponse(BaseModel):
    status: str
    message: str


class CvCalibrationFrameRequest(BaseModel):
    image_base64: str = Field(..., description="Base64 encoded JPEG/PNG frame from webcam")
    timestamp: Optional[float] = Field(None, description="Client frame timestamp")


class CvCalibrationFrameResponse(BaseModel):
    active: bool
    progress: float
    is_complete: bool
    face_detected: bool
    quality: str
    message: str


class CvBaselineModel(BaseModel):
    face_center_x: float
    face_center_y: float
    face_size: float
    baseline_yaw: float
    baseline_pitch: float
    baseline_roll: float
    normal_ear: float
    calibration_duration: float
    sample_count: int
    quality: str
    created_at: float


class CvQualityResponse(BaseModel):
    status: str
    face_visible: bool
    face_size_ratio: float
    brightness: float
    landmark_quality: float
    user_message: str
