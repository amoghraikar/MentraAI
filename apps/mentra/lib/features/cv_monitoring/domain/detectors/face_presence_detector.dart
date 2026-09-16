import '../models/monitoring_models.dart';

/// Temporal detector for face presence and absence confirmation.
class FacePresenceDetector {
  FacePresenceDetector({MonitoringConfig? config})
      : config = config ?? const MonitoringConfig();

  final MonitoringConfig config;

  DateTime? _absenceStartTime;
  bool _isCurrentlyAway = false;
  int _consecutiveAbsentFrames = 0;

  bool get isAway => _isCurrentlyAway;

  /// Ingests a new single-frame observation and evaluates presence state.
  FocusEvent? processObservation(FocusObservation observation) {
    final hasValidFace = observation.isFaceDetected &&
        observation.faceConfidence >= config.minConfidenceThreshold;

    if (hasValidFace) {
      // Face is clearly detected
      _absenceStartTime = null;
      _consecutiveAbsentFrames = 0;

      if (_isCurrentlyAway) {
        _isCurrentlyAway = false;
        return FocusEvent(
          id: 'evt_pres_${observation.timestamp.millisecondsSinceEpoch}',
          type: FocusEventType.focusPresent,
          timestamp: observation.timestamp,
          confidence: observation.faceConfidence,
          message: 'User returned to study view',
        );
      }
      return null;
    }

    // Face is missing or below confidence threshold
    _consecutiveAbsentFrames++;
    _absenceStartTime ??= observation.timestamp;

    final absentDuration =
        observation.timestamp.difference(_absenceStartTime!).inMilliseconds / 1000.0;

    // Trigger absence only after sustained temporal duration (not on single dropped frame)
    if (!_isCurrentlyAway &&
        absentDuration >= config.faceAbsentThresholdSeconds &&
        _consecutiveAbsentFrames >= 2) {
      _isCurrentlyAway = true;
      return FocusEvent(
        id: 'evt_away_${observation.timestamp.millisecondsSinceEpoch}',
        type: FocusEventType.faceAbsent,
        timestamp: observation.timestamp,
        duration: Duration(milliseconds: (absentDuration * 1000).round()),
        confidence: 0.9,
        message: 'User is away from study area',
        metadata: {'absent_seconds': absentDuration},
      );
    }

    return null;
  }

  void reset() {
    _absenceStartTime = null;
    _isCurrentlyAway = false;
    _consecutiveAbsentFrames = 0;
  }
}
