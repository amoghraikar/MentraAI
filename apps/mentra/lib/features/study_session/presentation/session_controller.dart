import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../cv_monitoring/domain/models/monitoring_models.dart';
import '../../cv_monitoring/domain/services/focus_monitoring_service.dart';
import '../../cv_monitoring/presentation/camera_feed_stub.dart'
    if (dart.library.html) '../../cv_monitoring/presentation/camera_feed_web.dart'
    as platform_cv;
import '../domain/models/session_config.dart';
import '../domain/models/study_session_record.dart';
import '../domain/repositories/session_repository.dart';

enum SessionState {
  idle,
  preparing,
  active,
  paused,
  completed,
}

class SessionController extends ChangeNotifier with WidgetsBindingObserver {
  SessionController({
    this.sessionRepository,
    IFocusMonitoringService? focusMonitoringService,
  }) : focusMonitoringService =
            focusMonitoringService ?? LocalFocusMonitoringService() {
    WidgetsBinding.instance.addObserver(this);
    _initMonitoringSubscriptions();
  }

  final SessionRepository? sessionRepository;
  final IFocusMonitoringService? focusMonitoringService;

  StreamSubscription<FocusEvent>? _focusEventSub;
  StreamSubscription<MonitoringStatus>? _focusStatusSub;

  SessionState _state = SessionState.idle;
  SessionConfig? _currentConfig;
  Timer? _ticker;

  // Timestamp-based timing engine
  DateTime? _sessionStartTime;
  DateTime? _currentSegmentStartTime;
  DateTime? _pausedAt;
  DateTime? _completedAt;
  int _accumulatedActiveSeconds = 0;
  int _targetSeconds = 0;
  int _finalElapsedSeconds = 0;

  int _distractionsCount = 0;
  int _focusScore = 100;
  FocusEvent? _latestAlertEvent;
  SessionReflection _selectedReflection = SessionReflection.good;
  StudySessionRecord? _lastSavedRecord;
  bool _isSaving = false;

  // Real observed CV durations
  double _totalObservedSeconds = 0.0;
  double _focusedDuration = 0.0;
  double _lookingAwayDuration = 0.0;
  double _eyesClosedDuration = 0.0;
  double _possibleDrowsinessDuration = 0.0;
  double _phoneDetectedDuration = 0.0;
  double _faceNotDetectedDuration = 0.0;
  double _unknownDuration = 0.0;
  DateTime? _lastObservationTime;

  SessionState get state => _state;
  SessionConfig? get currentConfig => _currentConfig;
  int get targetSeconds => _targetSeconds;
  int get distractionsCount => _distractionsCount;
  int get focusScore => _focusScore;

  // Duration getters
  double get totalObservedSeconds => _totalObservedSeconds;
  double get focusedDuration => _focusedDuration;
  double get lookingAwayDuration => _lookingAwayDuration;
  double get eyesClosedDuration => _eyesClosedDuration;
  double get possibleDrowsinessDuration => _possibleDrowsinessDuration;
  double get phoneDetectedDuration => _phoneDetectedDuration;
  double get faceNotDetectedDuration => _faceNotDetectedDuration;
  double get unknownDuration => _unknownDuration;

  // Backward-compatible aliases
  double get focusedSeconds => _focusedDuration;
  double get awaySeconds => _faceNotDetectedDuration;
  double get lookingAwaySeconds => _lookingAwayDuration;
  double get eyesClosedSeconds => _eyesClosedDuration;
  double get phoneDetectedSeconds => _phoneDetectedDuration;

  FocusEvent? get latestAlertEvent => _latestAlertEvent;
  SessionReflection get selectedReflection => _selectedReflection;
  StudySessionRecord? get lastSavedRecord => _lastSavedRecord;
  bool get isSaving => _isSaving;
  DateTime? get sessionStartTime => _sessionStartTime;
  DateTime? get pausedAt => _pausedAt;
  DateTime? get completedAt => _completedAt;
  FocusObservation? _latestObservation;
  FocusObservation? get latestObservation => _latestObservation;

  MonitoringStatus get monitoringStatus =>
      focusMonitoringService?.status ?? MonitoringStatus.uninitialized;

  void _initMonitoringSubscriptions() {
    if (focusMonitoringService != null) {
      _focusEventSub = focusMonitoringService!.eventStream.listen(_handleFocusEvent);
      _focusStatusSub = focusMonitoringService!.statusStream.listen((_) {
        notifyListeners();
      });
    }
  }

  void _handleFocusEvent(FocusEvent event) {
    if (_state != SessionState.active) return;

    if (event.type == FocusEventType.distractionDetected ||
        event.type == FocusEventType.drowsinessDetected ||
        event.type == FocusEventType.faceAbsent) {
      _distractionsCount++;
      _latestAlertEvent = event;
    }
    notifyListeners();
  }

  /// Ingest real-time verified CV observation emitted from webcam inference.
  void recordCvObservation(FocusObservation observation) {
    if (_state != SessionState.active) return;

    _latestObservation = observation;
    final now = observation.timestamp;
    if (_lastObservationTime != null) {
      final delta = now.difference(_lastObservationTime!).inMilliseconds / 1000.0;
      if (delta > 0 && delta < 5.0) {
        _accumulateObservation(observation, delta);
      }
    }
    _lastObservationTime = now;

    if (focusMonitoringService != null) {
      focusMonitoringService!.ingestObservation(observation);
    }
    notifyListeners();
  }

  void _accumulateObservation(FocusObservation observation, double delta) {
    final state = observation.focusState;
    if (state == 'UNKNOWN' ||
        state == 'CAMERA_ERROR' ||
        state == 'CV_INITIALIZING' ||
        state == 'RECOVERING' ||
        state == 'POSSIBLE_DISTRACTION') {
      _unknownDuration += delta;
    } else if (!observation.isFaceDetected || state == 'FACE_NOT_DETECTED') {
      _faceNotDetectedDuration += delta;
    } else if (state == 'PHONE_DETECTED' || observation.phoneDetected) {
      _phoneDetectedDuration += delta;
    } else if (state == 'POSSIBLE_DROWSINESS') {
      _possibleDrowsinessDuration += delta;
    } else if (state == 'EYES_CLOSED' || observation.eyeState == EyeState.closed) {
      _eyesClosedDuration += delta;
    } else if (state == 'LOOKING_AWAY' ||
        state == 'LOOKING_DOWN' ||
        state == 'LOOKING_UP' ||
        observation.isDistractionDetected) {
      _lookingAwayDuration += delta;
    } else {
      // FOCUSED
      _focusedDuration += delta;
    }

    _recalculateFocusScore();
  }

  void _recalculateFocusScore() {
    final confirmedObserved = _focusedDuration +
        _lookingAwayDuration +
        _eyesClosedDuration +
        _possibleDrowsinessDuration +
        _phoneDetectedDuration +
        _faceNotDetectedDuration;

    _totalObservedSeconds = confirmedObserved + _unknownDuration;

    if (confirmedObserved >= 3.0) {
      final ratio = _focusedDuration / confirmedObserved;
      _focusScore = (ratio * 100).round().clamp(0, 100);
    } else if (_distractionsCount > 0) {
      final penalty = _distractionsCount * 3;
      _focusScore = (92 - penalty).clamp(55, 98);
    } else {
      _focusScore = 100;
    }
  }

  /// Accurately computes elapsed study duration in seconds from real wall-clock timestamps.
  int get elapsedSeconds {
    if (_state == SessionState.completed) {
      return _finalElapsedSeconds;
    }
    if (_state == SessionState.active && _currentSegmentStartTime != null) {
      final currentSegment =
          DateTime.now().difference(_currentSegmentStartTime!).inSeconds;
      return _accumulatedActiveSeconds + max(0, currentSegment);
    }
    return _accumulatedActiveSeconds;
  }

  int get remainingSeconds {
    final remaining = _targetSeconds - elapsedSeconds;
    return remaining.clamp(0, _targetSeconds);
  }

  double get progressRatio {
    if (_targetSeconds <= 0) return 0.0;
    return (elapsedSeconds / _targetSeconds).clamp(0.0, 1.0);
  }

  String get formattedRemainingTime {
    final s = remainingSeconds;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String get formattedElapsedTime {
    final s = elapsedSeconds;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  /// Setup a new study session from idle or completed state.
  bool setupSession(SessionConfig config) {
    if (_state != SessionState.idle && _state != SessionState.completed) {
      return false;
    }

    _currentConfig = config;
    _targetSeconds = config.targetDurationMinutes * 60;
    _accumulatedActiveSeconds = 0;
    _finalElapsedSeconds = 0;
    _distractionsCount = 0;
    _focusScore = 100;
    _totalObservedSeconds = 0.0;
    _focusedDuration = 0.0;
    _lookingAwayDuration = 0.0;
    _eyesClosedDuration = 0.0;
    _possibleDrowsinessDuration = 0.0;
    _phoneDetectedDuration = 0.0;
    _faceNotDetectedDuration = 0.0;
    _unknownDuration = 0.0;
    _lastObservationTime = null;
    _latestAlertEvent = null;
    _sessionStartTime = null;
    _currentSegmentStartTime = null;
    _pausedAt = null;
    _completedAt = null;
    _lastSavedRecord = null;
    _isSaving = false;

    // Initialize CV monitoring service
    focusMonitoringService?.initialize();

    _state = SessionState.preparing;
    notifyListeners();
    return true;
  }

  /// Transition from preparing to active study state.
  bool startActiveSession() {
    if (_state != SessionState.preparing) {
      return false;
    }

    final now = DateTime.now();
    _sessionStartTime = now;
    _currentSegmentStartTime = now;
    _accumulatedActiveSeconds = 0;
    _state = SessionState.active;

    _startTicker();

    // Start CV Monitoring pipeline and backend tracking
    focusMonitoringService?.start();
    platform_cv.CameraFeedWebHelper.resumeMonitoring();

    notifyListeners();
    return true;
  }

  /// Pause an active session.
  bool pauseSession() {
    if (_state != SessionState.active) {
      return false;
    }

    _ticker?.cancel();
    final now = DateTime.now();
    _pausedAt = now;
    if (_currentSegmentStartTime != null) {
      _accumulatedActiveSeconds +=
          max(0, now.difference(_currentSegmentStartTime!).inSeconds);
    }
    _currentSegmentStartTime = null;
    _lastObservationTime = null;
    _state = SessionState.paused;

    // Pause CV Monitoring pipeline and freeze backend metrics
    focusMonitoringService?.pause();
    platform_cv.CameraFeedWebHelper.pauseMonitoring();

    notifyListeners();
    return true;
  }

  /// Resume a paused session.
  bool resumeSession() {
    if (_state != SessionState.paused) {
      return false;
    }

    _pausedAt = null;
    _currentSegmentStartTime = DateTime.now();
    _lastObservationTime = null;
    _state = SessionState.active;

    _startTicker();

    // Resume CV Monitoring pipeline and backend tracking
    focusMonitoringService?.resume();
    platform_cv.CameraFeedWebHelper.resumeMonitoring();

    notifyListeners();
    return true;
  }

  /// Complete study session (manual or timer-driven).
  bool endSession() {
    if (_state != SessionState.active && _state != SessionState.paused) {
      return false;
    }

    _ticker?.cancel();
    final now = DateTime.now();
    _completedAt = now;

    if (_state == SessionState.active && _currentSegmentStartTime != null) {
      _accumulatedActiveSeconds +=
          max(0, now.difference(_currentSegmentStartTime!).inSeconds);
    }
    _currentSegmentStartTime = null;
    _lastObservationTime = null;
    _finalElapsedSeconds = _accumulatedActiveSeconds;
    _state = SessionState.completed;

    // Stop and dispose CV resources on session end
    focusMonitoringService?.stop();
    platform_cv.CameraFeedWebHelper.resetSession();

    notifyListeners();
    return true;
  }

  /// Abort/cancel active session and return to idle.
  bool cancelSession() {
    endSession();
    reset();
    return true;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state == SessionState.active) {
        if (remainingSeconds <= 0) {
          endSession();
        } else {
          notifyListeners();
        }
      }
    });
  }

  void setReflection(SessionReflection reflection) {
    _selectedReflection = reflection;
    notifyListeners();
  }

  void clearAlert() {
    _latestAlertEvent = null;
    notifyListeners();
  }

  void dismissLatestAlert() => clearAlert();

  void recordDistraction([String? type]) {
    if (_state != SessionState.active) return;
    _distractionsCount++;
    _recalculateFocusScore();
    notifyListeners();
  }

  void ingestObservation(FocusObservation observation) =>
      recordCvObservation(observation);

  Future<StudySessionRecord?> saveCompletedSession() => saveSessionRecord();

  /// Persist session record to SQLite / API via repository.
  Future<StudySessionRecord?> saveSessionRecord() async {
    if (_state != SessionState.completed ||
        _currentConfig == null ||
        _sessionStartTime == null) {
      return null;
    }
    if (_isSaving) return _lastSavedRecord;

    _isSaving = true;
    notifyListeners();

    try {
      final record = StudySessionRecord(
        id: 'sess_${_sessionStartTime!.millisecondsSinceEpoch}',
        subjectId: _currentConfig!.subjectId,
        topicId: _currentConfig!.topicId,
        subjectTitle: _currentConfig!.subjectTitle,
        topicTitle: _currentConfig!.topicTitle,
        durationMinutes: max(1, _finalElapsedSeconds ~/ 60),
        focusScore: _focusScore,
        distractionsCount: _distractionsCount,
        completedAt: _completedAt ?? DateTime.now(),
        reflection: _selectedReflection,
      );

      if (sessionRepository != null) {
        await sessionRepository!.saveSession(record);
      }

      _lastSavedRecord = record;
      _isSaving = false;
      _state = SessionState.idle;
      notifyListeners();
      return record;
    } catch (_) {
      _isSaving = false;
      notifyListeners();
      return null;
    }
  }

  /// Reset back to initial idle state.
  void reset() {
    _ticker?.cancel();
    _state = SessionState.idle;
    _currentConfig = null;
    _accumulatedActiveSeconds = 0;
    _finalElapsedSeconds = 0;
    _distractionsCount = 0;
    _focusScore = 100;
    _totalObservedSeconds = 0.0;
    _focusedDuration = 0.0;
    _lookingAwayDuration = 0.0;
    _eyesClosedDuration = 0.0;
    _possibleDrowsinessDuration = 0.0;
    _phoneDetectedDuration = 0.0;
    _faceNotDetectedDuration = 0.0;
    _unknownDuration = 0.0;
    _lastObservationTime = null;
    _latestAlertEvent = null;
    _sessionStartTime = null;
    _currentSegmentStartTime = null;
    _pausedAt = null;
    _completedAt = null;
    _lastSavedRecord = null;
    _isSaving = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _state == SessionState.active) {
      pauseSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _focusEventSub?.cancel();
    _focusStatusSub?.cancel();
    focusMonitoringService?.dispose();
    super.dispose();
  }
}
