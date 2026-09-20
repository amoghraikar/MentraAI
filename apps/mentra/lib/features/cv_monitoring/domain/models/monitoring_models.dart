import 'dart:ui';

/// Types of focus monitoring events emitted by the event engine.
enum FocusEventType {
  focusPresent,
  faceAbsent,
  eyesClosed,
  drowsinessDetected,
  distractionDetected,
  cameraUnavailable,
  monitoringPaused,
}

/// Lifecycle status of the CV Focus Monitoring service.
enum MonitoringStatus {
  uninitialized,
  requestingPermission,
  calibrating,
  ready,
  running,
  paused,
  stopped,
  permissionDenied,
  unavailable,
  error,
}

/// Instantaneous eye detection state.
enum EyeState {
  open,
  closed,
  uncertain,
}

/// Session baseline established during calibration without storing biometric identity.
class CVBaseline {
  const CVBaseline({
    required this.faceCenterX,
    required this.faceCenterY,
    required this.faceSize,
    required this.baselineYaw,
    required this.baselinePitch,
    required this.baselineRoll,
    required this.normalEar,
    required this.calibrationDuration,
    required this.sampleCount,
    required this.quality,
    required this.createdAt,
  });

  final double faceCenterX;
  final double faceCenterY;
  final double faceSize;
  final double baselineYaw;
  final double baselinePitch;
  final double baselineRoll;
  final double normalEar;
  final double calibrationDuration;
  final int sampleCount;
  final String quality;
  final double createdAt;

  factory CVBaseline.fromJson(Map<String, dynamic> json) => CVBaseline(
        faceCenterX: (json['face_center_x'] as num?)?.toDouble() ?? 0.5,
        faceCenterY: (json['face_center_y'] as num?)?.toDouble() ?? 0.5,
        faceSize: (json['face_size'] as num?)?.toDouble() ?? 0.1,
        baselineYaw: (json['baseline_yaw'] as num?)?.toDouble() ?? 0.0,
        baselinePitch: (json['baseline_pitch'] as num?)?.toDouble() ?? 0.0,
        baselineRoll: (json['baseline_roll'] as num?)?.toDouble() ?? 0.0,
        normalEar: (json['normal_ear'] as num?)?.toDouble() ?? 0.28,
        calibrationDuration:
            (json['calibration_duration'] as num?)?.toDouble() ?? 3.0,
        sampleCount: (json['sample_count'] as num?)?.toInt() ?? 0,
        quality: (json['quality'] as String?) ?? 'GOOD',
        createdAt: (json['created_at'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'face_center_x': faceCenterX,
        'face_center_y': faceCenterY,
        'face_size': faceSize,
        'baseline_yaw': baselineYaw,
        'baseline_pitch': baselinePitch,
        'baseline_roll': baselineRoll,
        'normal_ear': normalEar,
        'calibration_duration': calibrationDuration,
        'sample_count': sampleCount,
        'quality': quality,
        'created_at': createdAt,
      };
}

/// Camera condition evaluation result.
class CameraQualityInfo {
  const CameraQualityInfo({
    required this.status,
    required this.faceVisible,
    required this.faceSizeRatio,
    required this.brightness,
    required this.landmarkQuality,
    required this.userMessage,
  });

  final String status; // GOOD, FAIR, POOR, UNAVAILABLE
  final bool faceVisible;
  final double faceSizeRatio;
  final double brightness;
  final double landmarkQuality;
  final String userMessage;

  factory CameraQualityInfo.fromJson(Map<String, dynamic> json) =>
      CameraQualityInfo(
        status: (json['status'] as String?) ?? 'UNKNOWN',
        faceVisible: (json['face_visible'] as bool?) ?? false,
        faceSizeRatio: (json['face_size_ratio'] as num?)?.toDouble() ?? 0.0,
        brightness: (json['brightness'] as num?)?.toDouble() ?? 0.0,
        landmarkQuality:
            (json['landmark_quality'] as num?)?.toDouble() ?? 0.0,
        userMessage: (json['user_message'] as String?) ?? '',
      );

  factory CameraQualityInfo.uninitialized() => const CameraQualityInfo(
        status: 'UNAVAILABLE',
        faceVisible: false,
        faceSizeRatio: 0.0,
        brightness: 0.0,
        landmarkQuality: 0.0,
        userMessage: 'Initializing camera feed...',
      );
}

/// Normalized single-frame observation emitted from the CV inference pipeline.
class FocusObservation {
  const FocusObservation({
    required this.timestamp,
    required this.isFaceDetected,
    this.faceBoundingBox,
    this.faceConfidence = 0.0,
    this.eyeState = EyeState.uncertain,
    this.eyeOpenProbability = 1.0,
    this.isDistractionDetected = false,
    this.distractionConfidence = 0.0,
    this.distractionType,
    this.phoneDetected = false,
    this.phoneConfidence = 0.0,
    this.phoneAvailable = false,
    this.ear,
    this.yaw,
    this.pitch,
    this.roll,
    this.yawDeviation,
    this.pitchDeviation,
    this.rollDeviation,
    this.focusState,
    this.cameraQuality,
    this.confidenceLevel,
  });

  final DateTime timestamp;
  final bool isFaceDetected;
  final Rect? faceBoundingBox;
  final double faceConfidence;
  final EyeState eyeState;
  final double eyeOpenProbability;
  final bool isDistractionDetected;
  final double distractionConfidence;
  final String? distractionType;
  final bool phoneDetected;
  final double phoneConfidence;
  final bool phoneAvailable;
  final double? ear;
  final double? yaw;
  final double? pitch;
  final double? roll;
  final double? yawDeviation;
  final double? pitchDeviation;
  final double? rollDeviation;
  final String? focusState;
  final CameraQualityInfo? cameraQuality;
  final String? confidenceLevel;

  /// Synthetic focused observation helper for tests
  factory FocusObservation.focused([DateTime? timestamp]) => FocusObservation(
        timestamp: timestamp ?? DateTime.now(),
        isFaceDetected: true,
        faceBoundingBox: const Rect.fromLTWH(0.2, 0.2, 0.6, 0.6),
        faceConfidence: 0.95,
        eyeState: EyeState.open,
        eyeOpenProbability: 0.95,
        ear: 0.28,
        yaw: 0.0,
        pitch: 0.0,
        roll: 0.0,
        yawDeviation: 0.0,
        pitchDeviation: 0.0,
        rollDeviation: 0.0,
        focusState: 'FOCUSED',
      );

  /// Synthetic face-absent observation helper for tests
  factory FocusObservation.away([DateTime? timestamp]) => FocusObservation(
        timestamp: timestamp ?? DateTime.now(),
        isFaceDetected: false,
        faceConfidence: 0.0,
        eyeState: EyeState.uncertain,
        eyeOpenProbability: 0.0,
        focusState: 'FACE_NOT_DETECTED',
      );

  /// Synthetic closed-eyes observation helper for tests
  factory FocusObservation.eyesClosed([DateTime? timestamp]) => FocusObservation(
        timestamp: timestamp ?? DateTime.now(),
        isFaceDetected: true,
        faceBoundingBox: const Rect.fromLTWH(0.2, 0.2, 0.6, 0.6),
        faceConfidence: 0.92,
        eyeState: EyeState.closed,
        eyeOpenProbability: 0.05,
        ear: 0.12,
        focusState: 'POSSIBLE_DROWSINESS',
      );

  /// Synthetic distraction observation helper for tests
  factory FocusObservation.distracted([DateTime? timestamp, String? type]) =>
      FocusObservation(
        timestamp: timestamp ?? DateTime.now(),
        isFaceDetected: true,
        faceBoundingBox: const Rect.fromLTWH(0.2, 0.2, 0.6, 0.6),
        faceConfidence: 0.88,
        eyeState: EyeState.open,
        isDistractionDetected: true,
        distractionConfidence: 0.85,
        distractionType: type ?? 'phone',
        phoneDetected: type == 'phone',
        phoneConfidence: type == 'phone' ? 0.85 : 0.0,
        focusState: type == 'phone' ? 'PHONE_DETECTED' : 'LOOKING_AWAY',
      );
}

/// Stable behavioral focus event derived by temporal smoothing and debounce logic.
class FocusEvent {
  const FocusEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    this.duration,
    this.confidence = 1.0,
    this.message,
    this.metadata = const {},
  });

  final String id;
  final FocusEventType type;
  final DateTime timestamp;
  final Duration? duration;
  final double confidence;
  final String? message;
  final Map<String, dynamic> metadata;

  @override
  String toString() =>
      'FocusEvent(type: $type, timestamp: $timestamp, confidence: $confidence)';
}

/// Configurable thresholds for computer vision and temporal smoothing.
class MonitoringConfig {
  const MonitoringConfig({
    this.frameThrottleIntervalMs = 200,
    this.minConfidenceThreshold = 0.60,
    this.faceAbsentThresholdSeconds = 2.0,
    this.drowsinessDurationThresholdSeconds = 1.5,
    this.distractionDurationThresholdSeconds = 1.5,
    this.alertCooldownSeconds = 6.0,
  });

  final int frameThrottleIntervalMs;
  final double minConfidenceThreshold;
  final double faceAbsentThresholdSeconds;
  final double drowsinessDurationThresholdSeconds;
  final double distractionDurationThresholdSeconds;
  final double alertCooldownSeconds;
}

/// Instantaneous computer vision telemetry emitted from the live camera stream.
class RealTimeCvTelemetry {
  const RealTimeCvTelemetry({
    required this.isFaceDetected,
    required this.confidence,
    required this.box,
    required this.landmarks,
    required this.yaw,
    required this.pitch,
    required this.roll,
    this.yawDeviation = 0.0,
    this.pitchDeviation = 0.0,
    this.rollDeviation = 0.0,
    required this.attentionScore,
    required this.ear,
    required this.leftEar,
    required this.rightEar,
    required this.phoneDetected,
    required this.phoneConfidence,
    this.phoneAvailable = false,
    required this.orientation,
    required this.focusState,
    this.eyeState = 'NORMAL_OPEN',
    this.confidenceLevel = 'UNKNOWN',
    this.cameraQuality = const CameraQualityInfo(
      status: 'GOOD',
      faceVisible: true,
      faceSizeRatio: 0.1,
      brightness: 120.0,
      landmarkQuality: 1.0,
      userMessage: 'Optimal camera conditions',
    ),
    required this.fps,
    required this.latencyMs,
    required this.statusMessage,
    this.baselineActive = false,
    this.focusedDuration = 0.0,
    this.lookingAwayDuration = 0.0,
    this.eyesClosedDuration = 0.0,
    this.possibleDrowsinessDuration = 0.0,
    this.phoneDetectedDuration = 0.0,
    this.faceNotDetectedDuration = 0.0,
    this.unknownDuration = 0.0,
    this.distractionCount = 0,
    this.focusScore,
  });

  final bool isFaceDetected;
  final double confidence;
  final Rect box;
  final List<Offset> landmarks;
  final double yaw;
  final double pitch;
  final double roll;
  final double yawDeviation;
  final double pitchDeviation;
  final double rollDeviation;
  final double attentionScore;
  final double ear;
  final double leftEar;
  final double rightEar;
  final bool phoneDetected;
  final double phoneConfidence;
  final bool phoneAvailable;
  final String orientation;
  final String focusState;
  final String eyeState;
  final String confidenceLevel;
  final CameraQualityInfo cameraQuality;
  final int fps;
  final double latencyMs;
  final String statusMessage;
  final bool baselineActive;

  // Session metrics breakdown
  final double focusedDuration;
  final double lookingAwayDuration;
  final double eyesClosedDuration;
  final double possibleDrowsinessDuration;
  final double phoneDetectedDuration;
  final double faceNotDetectedDuration;
  final double unknownDuration;
  final int distractionCount;
  final int? focusScore;

  factory RealTimeCvTelemetry.uninitialized() => const RealTimeCvTelemetry(
        isFaceDetected: false,
        confidence: 0.0,
        box: Rect.fromLTWH(0.25, 0.20, 0.50, 0.55),
        landmarks: [],
        yaw: 0.0,
        pitch: 0.0,
        roll: 0.0,
        yawDeviation: 0.0,
        pitchDeviation: 0.0,
        rollDeviation: 0.0,
        attentionScore: 0.0,
        ear: 0.0,
        leftEar: 0.0,
        rightEar: 0.0,
        phoneDetected: false,
        phoneConfidence: 0.0,
        phoneAvailable: false,
        orientation: 'UNKNOWN',
        focusState: 'UNINITIALIZED',
        confidenceLevel: 'UNKNOWN',
        cameraQuality: CameraQualityInfo(
          status: 'UNAVAILABLE',
          faceVisible: false,
          faceSizeRatio: 0.0,
          brightness: 0.0,
          landmarkQuality: 0.0,
          userMessage: 'Initializing camera feed...',
        ),
        fps: 0,
        latencyMs: 0.0,
        statusMessage: 'INITIALIZING CV ENGINE...',
      );

  factory RealTimeCvTelemetry.defaultFace() => const RealTimeCvTelemetry(
        isFaceDetected: true,
        confidence: 0.95,
        box: Rect.fromLTWH(0.25, 0.18, 0.50, 0.58),
        landmarks: [
          Offset(0.38, 0.35),
          Offset(0.62, 0.35),
          Offset(0.50, 0.48),
          Offset(0.50, 0.62),
        ],
        yaw: 0.0,
        pitch: 0.0,
        roll: 0.0,
        yawDeviation: 0.0,
        pitchDeviation: 0.0,
        rollDeviation: 0.0,
        attentionScore: 0.95,
        ear: 0.28,
        leftEar: 0.28,
        rightEar: 0.28,
        phoneDetected: false,
        phoneConfidence: 0.0,
        phoneAvailable: false,
        orientation: 'NORMAL_FORWARD',
        focusState: 'FOCUSED',
        confidenceLevel: 'HIGH_CONFIDENCE',
        fps: 30,
        latencyMs: 12.0,
        statusMessage: 'FOCUSED ON MATERIAL',
      );
}
