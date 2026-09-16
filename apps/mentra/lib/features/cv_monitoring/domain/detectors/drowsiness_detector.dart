import '../models/monitoring_models.dart';

/// Temporal detector for drowsiness and prolonged eye closure.
class DrowsinessDetector {
  DrowsinessDetector({MonitoringConfig? config})
      : config = config ?? const MonitoringConfig();

  final MonitoringConfig config;

  DateTime? _closureStartTime;
  bool _isDrowsinessTriggered = false;
  int _consecutiveClosedFrames = 0;

  bool get isDrowsy => _isDrowsinessTriggered;

  /// Ingests single-frame observation and evaluates eye closure duration.
  FocusEvent? processObservation(FocusObservation observation) {
    if (!observation.isFaceDetected ||
        observation.faceConfidence < config.minConfidenceThreshold) {
      // If face is absent, pause eye tracking
      return null;
    }

    final isEyesClosed = observation.eyeState == EyeState.closed ||
        (observation.eyeState != EyeState.uncertain &&
            observation.eyeOpenProbability < 0.25);

    if (isEyesClosed) {
      _consecutiveClosedFrames++;
      _closureStartTime ??= observation.timestamp;

      final closedDurationSeconds =
          observation.timestamp.difference(_closureStartTime!).inMilliseconds / 1000.0;

      // Check if continuous eye closure duration satisfies the drowsiness threshold (e.g. >= 2.0s)
      // and is more than a single transient frame
      if (!_isDrowsinessTriggered &&
          closedDurationSeconds >= config.drowsinessDurationThresholdSeconds &&
          _consecutiveClosedFrames >= 3) {
        _isDrowsinessTriggered = true;
        return FocusEvent(
          id: 'evt_drowsy_${observation.timestamp.millisecondsSinceEpoch}',
          type: FocusEventType.drowsinessDetected,
          timestamp: observation.timestamp,
          duration: Duration(milliseconds: (closedDurationSeconds * 1000).round()),
          confidence: 0.92,
          message: 'Sustained eye closure detected (drowsiness signal)',
          metadata: {
            'closed_duration_seconds': closedDurationSeconds,
            'eye_open_probability': observation.eyeOpenProbability,
          },
        );
      }
    } else if (observation.eyeState == EyeState.open ||
        observation.eyeOpenProbability >= 0.60) {
      // Eyes clearly open -> reset drowsiness state and closure buffer
      _closureStartTime = null;
      _consecutiveClosedFrames = 0;
      _isDrowsinessTriggered = false;
    }

    return null;
  }

  void reset() {
    _closureStartTime = null;
    _isDrowsinessTriggered = false;
    _consecutiveClosedFrames = 0;
  }
}
