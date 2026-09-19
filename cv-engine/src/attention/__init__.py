"""Real Head Pose Estimation Module using OpenCV solvePnP and 3D Facial Landmarks."""

from dataclasses import dataclass
from typing import List, Optional
import cv2
import numpy as np


@dataclass
class HeadPoseResult:
    yaw: float  # Degrees (-180 to +180): negative = left, positive = right
    pitch: float  # Degrees (-180 to +180): positive = looking down, negative = looking up
    roll: float  # Degrees: head tilt
    orientation: str  # NORMAL_FORWARD, LOOKING_AWAY, LOOKING_DOWN, LOOKING_UP, UNKNOWN


class HeadPoseEstimator:
    """Estimates real 3D head pose (Yaw, Pitch, Roll) using OpenCV solvePnP."""

    # 3D generic facial model points in world space (mm)
    MODEL_POINTS_3D = np.array(
        [
            (0.0, 0.0, 0.0),  # Nose tip (index 1)
            (0.0, -330.0, -65.0),  # Chin (index 152)
            (-225.0, 170.0, -135.0),  # Left eye outer corner (index 33)
            (225.0, 170.0, -135.0),  # Right eye outer corner (index 263)
            (-150.0, -150.0, -125.0),  # Left mouth corner (index 61)
            (150.0, -150.0, -125.0),  # Right mouth corner (index 291)
        ],
        dtype=np.float64,
    )

    LANDMARK_INDICES = [1, 152, 33, 263, 61, 291]

    def __init__(
        self,
        yaw_threshold: float = 18.0,
        pitch_down_threshold: float = 15.0,
        pitch_up_threshold: float = -18.0,
    ) -> None:
        self.yaw_threshold = yaw_threshold
        self.pitch_down_threshold = pitch_down_threshold
        self.pitch_up_threshold = pitch_up_threshold

    def process(
        self,
        landmarks: Optional[List],
        img_w: int = 640,
        img_h: int = 480,
    ) -> HeadPoseResult:
        """Estimate 3D head orientation from face landmarks."""
        if not landmarks or len(landmarks) < 468:
            return HeadPoseResult(
                yaw=0.0,
                pitch=0.0,
                roll=0.0,
                orientation="UNKNOWN",
            )

        # 2D image points
        image_points = np.array(
            [
                (landmarks[idx].x * img_w, landmarks[idx].y * img_h)
                for idx in self.LANDMARK_INDICES
            ],
            dtype=np.float64,
        )

        # Camera matrix approximation
        focal_length = img_w
        center = (img_w / 2.0, img_h / 2.0)
        camera_matrix = np.array(
            [
                [focal_length, 0, center[0]],
                [0, focal_length, center[1]],
                [0, 0, 1],
            ],
            dtype=np.float64,
        )
        dist_coeffs = np.zeros((4, 1), dtype=np.float64)

        success, rvec, tvec = cv2.solvePnP(
            self.MODEL_POINTS_3D,
            image_points,
            camera_matrix,
            dist_coeffs,
            flags=cv2.SOLVEPNP_ITERATIVE,
        )

        if not success:
            return HeadPoseResult(yaw=0.0, pitch=0.0, roll=0.0, orientation="UNKNOWN")

        rotation_matrix, _ = cv2.Rodrigues(rvec)
        euler_angles = cv2.RQDecomp3x3(rotation_matrix)[0]

        # OpenCV Euler angles convention
        raw_pitch = float(euler_angles[0])
        raw_yaw = float(euler_angles[1])
        raw_roll = float(euler_angles[2])

        # Normalize yaw so that looking left is negative, right is positive
        # In webcam mirrored/standard coordinates, normalize signs:
        yaw = round(raw_yaw, 1)
        pitch = round(raw_pitch, 1)
        roll = round(raw_roll, 1)

        # Classify orientation
        if abs(yaw) > self.yaw_threshold:
            orientation = "LOOKING_AWAY"
        elif pitch > self.pitch_down_threshold:
            orientation = "LOOKING_DOWN"
        elif pitch < self.pitch_up_threshold:
            orientation = "LOOKING_UP"
        else:
            orientation = "NORMAL_FORWARD"

        return HeadPoseResult(
            yaw=yaw,
            pitch=pitch,
            roll=roll,
            orientation=orientation,
        )
