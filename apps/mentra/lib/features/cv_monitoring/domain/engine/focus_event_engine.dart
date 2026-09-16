import 'dart:async';
import '../detectors/distraction_detector.dart';
import '../detectors/drowsiness_detector.dart';
import '../detectors/face_presence_detector.dart';
import '../models/monitoring_models.dart';

/// Aggregates detector outputs, applies temporal smoothing, confidence gating,
/// and alert cooldowns to produce non-spammy, reliable focus events.
class FocusEventEngine {
  FocusEventEngine({
    MonitoringConfig? config,
    FacePresenceDetector? facePresenceDetector,
    DrowsinessDetector? drowsinessDetector,
    DistractionDetector? distractionDetector,
  })  : config = config ?? const MonitoringConfig(),
        _facePresenceDetector = facePresenceDetector ??
            FacePresenceDetector(config: config ?? const MonitoringConfig()),
        _drowsinessDetector = drowsinessDetector ??
            DrowsinessDetector(config: config ?? const MonitoringConfig()),
        _distractionDetector = distractionDetector ??
            DistractionDetector(config: config ?? const MonitoringConfig()) {
    _eventController = StreamController<FocusEvent>.broadcast();
  }

  final MonitoringConfig config;
  final FacePresenceDetector _facePresenceDetector;
  final DrowsinessDetector _drowsinessDetector;
  final DistractionDetector _distractionDetector;

  late final StreamController<FocusEvent> _eventController;

  // Alert Cooldown Tracker
  DateTime? _lastDrowsinessAlertTime;
  DateTime? _lastDistractionAlertTime;
  DateTime? _lastAwayAlertTime;

  // Telemetry Aggregates
  int _drowsinessEventCount = 0;
  int _distractionEventCount = 0;
  int _awayEventCount = 0;
  final List<FocusEvent> _eventHistory = [];

  Stream<FocusEvent> get eventStream => _eventController.stream;
  List<FocusEvent> get eventHistory => List.unmodifiable(_eventHistory);
  int get drowsinessEventCount => _drowsinessEventCount;
  int get distractionEventCount => _distractionEventCount;
  int get awayEventCount => _awayEventCount;
  int get totalInterventionCount =>
      _drowsinessEventCount + _distractionEventCount + _awayEventCount;

  /// Process a single frame observation through the detector pipeline.
  List<FocusEvent> ingestObservation(FocusObservation observation) {
    final emittedEvents = <FocusEvent>[];

    // 1. Face Presence / Absence
    final faceEvent = _facePresenceDetector.processObservation(observation);
    if (faceEvent != null) {
      if (faceEvent.type == FocusEventType.faceAbsent) {
        if (_shouldEmitAlert(_lastAwayAlertTime, observation.timestamp)) {
          _lastAwayAlertTime = observation.timestamp;
          _awayEventCount++;
          _emit(faceEvent);
          emittedEvents.add(faceEvent);
        }
      } else {
        // Returned to view / focusPresent -> always emit immediately without cooldown
        _emit(faceEvent);
        emittedEvents.add(faceEvent);
      }
    }

    // If user is currently confirmed away, do not process eye or distraction signals
    if (_facePresenceDetector.isAway) {
      return emittedEvents;
    }

    // 2. Drowsiness / Eye Closure
    final drowsyEvent = _drowsinessDetector.processObservation(observation);
    if (drowsyEvent != null) {
      if (_shouldEmitAlert(_lastDrowsinessAlertTime, observation.timestamp)) {
        _lastDrowsinessAlertTime = observation.timestamp;
        _drowsinessEventCount++;
        _emit(drowsyEvent);
        emittedEvents.add(drowsyEvent);
      }
    }

    // 3. Distraction (e.g. Phone, Look Away)
    final distractionEvent = _distractionDetector.processObservation(observation);
    if (distractionEvent != null) {
      if (_shouldEmitAlert(_lastDistractionAlertTime, observation.timestamp)) {
        _lastDistractionAlertTime = observation.timestamp;
        _distractionEventCount++;
        _emit(distractionEvent);
        emittedEvents.add(distractionEvent);
      }
    }

    return emittedEvents;
  }

  bool _shouldEmitAlert(DateTime? lastAlertTime, DateTime currentTimestamp) {
    if (lastAlertTime == null) return true;
    final elapsedSeconds =
        currentTimestamp.difference(lastAlertTime).inMilliseconds / 1000.0;
    return elapsedSeconds >= config.alertCooldownSeconds;
  }

  void _emit(FocusEvent event) {
    _eventHistory.add(event);
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Reset all detectors, cooldowns, and telemetry counters.
  void reset() {
    _facePresenceDetector.reset();
    _drowsinessDetector.reset();
    _distractionDetector.reset();
    _lastDrowsinessAlertTime = null;
    _lastDistractionAlertTime = null;
    _lastAwayAlertTime = null;
    _drowsinessEventCount = 0;
    _distractionEventCount = 0;
    _awayEventCount = 0;
    _eventHistory.clear();
  }

  void dispose() {
    _eventController.close();
  }
}
