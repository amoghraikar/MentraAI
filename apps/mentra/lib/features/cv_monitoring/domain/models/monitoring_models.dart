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

  /// Synthetic focused observation helper for tests
  factory FocusObservation.focused([DateTime? timestamp]) => FocusObservation(
        timestamp: timestamp ?? DateTime.now(),
        isFaceDetected: true,
        faceBoundingBox: const Rect.fromLTWH(0.2, 0.2, 0.6, 0.6),
        faceConfidence: 0.95,
        eyeState: EyeState.open,
        eyeOpenProbability: 0.95,
      );

  /// Synthetic face-absent observation helper for tests
  factory FocusObservation.away([DateTime? timestamp]) => FocusObservation(
        timestamp: timestamp ?? DateTime.now(),
        isFaceDetected: false,
        faceConfidence: 0.0,
        eyeState: EyeState.uncertain,
        eyeOpenProbability: 0.0,
      );

  /// Synthetic closed-eyes observation helper for tests
  factory FocusObservation.eyesClosed([DateTime? timestamp]) => FocusObservation(
        timestamp: timestamp ?? DateTime.now(),
        isFaceDetected: true,
        faceBoundingBox: const Rect.fromLTWH(0.2, 0.2, 0.6, 0.6),
        faceConfidence: 0.92,
        eyeState: EyeState.closed,
        eyeOpenProbability: 0.05,
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
    this.frameThrottleIntervalMs = 300,
    this.minConfidenceThreshold = 0.60,
    this.faceAbsentThresholdSeconds = 4.0,
    this.drowsinessDurationThresholdSeconds = 2.0,
    this.distractionDurationThresholdSeconds = 2.5,
    this.alertCooldownSeconds = 20.0,
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
