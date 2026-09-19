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
    this.focusState,
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
  final String? focusState;

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
  factory FocusObservation.distracted([DateTime? timestamp, String? type]) => FocusObservation(
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
  String toString() => 'FocusEvent(type: $type, timestamp: $timestamp, confidence: $confidence)';
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

  /// Time interval between consecutive CV inference frames (in ms).
  final int frameThrottleIntervalMs;

  /// Minimum confidence for an inference result to be considered valid.
  final double minConfidenceThreshold;

  /// Continuous duration of missing face before emitting a [FocusEventType.faceAbsent] event.
  final double faceAbsentThresholdSeconds;

  /// Continuous duration of closed eyes before emitting a [FocusEventType.drowsinessDetected] event.
  final double drowsinessDurationThresholdSeconds;

  /// Continuous duration of distraction detection before emitting [FocusEventType.distractionDetected].
  final double distractionDurationThresholdSeconds;

  /// Cooldown between user-facing intervention alerts to prevent alert fatigue.
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
    required this.attentionScore,
    required this.ear,
    required this.leftEar,
    required this.rightEar,
    required this.phoneDetected,
    required this.phoneConfidence,
    this.phoneAvailable = false,
    required this.orientation,
    required this.focusState,
    required this.fps,
    required this.latencyMs,
    required this.statusMessage,
  });

  final bool isFaceDetected;
  final double confidence;
  final Rect box; // 0.0 to 1.0 normalized bounds in video coordinates
  final List<Offset> landmarks; // normalized offsets: [leftEye, rightEye, nose, mouth]
  final double yaw; // head yaw in degrees (negative = left, positive = right)
  final double pitch; // head pitch in degrees (positive = looking down)
  final double roll; // head roll in degrees
  final double attentionScore; // 0.0 to 1.0
  final double ear; // Eye Aspect Ratio (0.0 to 0.5)
  final double leftEar;
  final double rightEar;
  final bool phoneDetected;
  final double phoneConfidence;
  final bool phoneAvailable;
  final String orientation;
  final String focusState;
  final int fps; // Measured processing frames per second
  final double latencyMs; // Processing inference latency in ms
  final String statusMessage;

  factory RealTimeCvTelemetry.uninitialized() => const RealTimeCvTelemetry(
        isFaceDetected: false,
        confidence: 0.0,
        box: Rect.fromLTWH(0.25, 0.20, 0.50, 0.55),
        landmarks: [],
        yaw: 0.0,
        pitch: 0.0,
        roll: 0.0,
        attentionScore: 0.0,
        ear: 0.0,
        leftEar: 0.0,
        rightEar: 0.0,
        phoneDetected: false,
        phoneConfidence: 0.0,
        phoneAvailable: false,
        orientation: 'UNKNOWN',
        focusState: 'UNINITIALIZED',
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
        attentionScore: 0.95,
        ear: 0.28,
        leftEar: 0.28,
        rightEar: 0.28,
        phoneDetected: false,
        phoneConfidence: 0.0,
        phoneAvailable: false,
        orientation: 'NORMAL_FORWARD',
        focusState: 'FOCUSED',
        fps: 30,
        latencyMs: 12.0,
        statusMessage: 'FOCUSED ON MATERIAL',
      );
}

