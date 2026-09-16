import '../models/monitoring_models.dart';

/// Temporal detector for distraction behaviors (phone usage, looking away).
class DistractionDetector {
  DistractionDetector({MonitoringConfig? config})
      : config = config ?? const MonitoringConfig();

  final MonitoringConfig config;

  DateTime? _distractionStartTime;
  bool _isDistractionActive = false;
  int _consecutiveDistractedFrames = 0;

  bool get isDistracted => _isDistractionActive;

  /// Ingests single-frame observation and evaluates distraction state.
  FocusEvent? processObservation(FocusObservation observation) {
    final isDistracted = observation.isDistractionDetected &&
        observation.distractionConfidence >= config.minConfidenceThreshold;

    if (isDistracted) {
      _consecutiveDistractedFrames++;
      _distractionStartTime ??= observation.timestamp;

      final distractionDuration =
          observation.timestamp.difference(_distractionStartTime!).inMilliseconds / 1000.0;

      // Trigger distraction event only after confirmed temporal duration
      if (!_isDistractionActive &&
          distractionDuration >= config.distractionDurationThresholdSeconds &&
          _consecutiveDistractedFrames >= 2) {
        _isDistractionActive = true;
        return FocusEvent(
          id: 'evt_distr_${observation.timestamp.millisecondsSinceEpoch}',
          type: FocusEventType.distractionDetected,
          timestamp: observation.timestamp,
          duration: Duration(milliseconds: (distractionDuration * 1000).round()),
          confidence: observation.distractionConfidence,
          message: 'Distraction activity detected (${observation.distractionType ?? 'phone'})',
          metadata: {
            'distraction_type': observation.distractionType ?? 'general',
            'duration_seconds': distractionDuration,
          },
        );
      }
    } else {
      // Normal focus / no distraction
      _distractionStartTime = null;
      _consecutiveDistractedFrames = 0;
      _isDistractionActive = false;
    }

    return null;
  }

  void reset() {
    _distractionStartTime = null;
    _isDistractionActive = false;
    _consecutiveDistractedFrames = 0;
  }
}
