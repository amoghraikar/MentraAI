import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../cv_monitoring/domain/models/monitoring_models.dart';
import '../../cv_monitoring/domain/services/focus_monitoring_service.dart';
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
  double _focusedSeconds = 0.0;
  double _awaySeconds = 0.0;
  double _lookingAwaySeconds = 0.0;
  double _eyesClosedSeconds = 0.0;
  double _phoneDetectedSeconds = 0.0;
  DateTime? _lastObservationTime;

  SessionState get state => _state;
  SessionConfig? get currentConfig => _currentConfig;
  int get targetSeconds => _targetSeconds;
  int get distractionsCount => _distractionsCount;
  int get focusScore => _focusScore;
  double get totalObservedSeconds => _totalObservedSeconds;
  double get focusedSeconds => _focusedSeconds;
  double get awaySeconds => _awaySeconds;
  double get lookingAwaySeconds => _lookingAwaySeconds;
  double get eyesClosedSeconds => _eyesClosedSeconds;
  double get phoneDetectedSeconds => _phoneDetectedSeconds;
  FocusEvent? get latestAlertEvent => _latestAlertEvent;
  SessionReflection get selectedReflection => _selectedReflection;
  StudySessionRecord? get lastSavedRecord => _lastSavedRecord;
  bool get isSaving => _isSaving;
  DateTime? get sessionStartTime => _sessionStartTime;
  DateTime? get pausedAt => _pausedAt;
  DateTime? get completedAt => _completedAt;

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
      notifyListeners();
    } else if (event.type == FocusEventType.focusPresent) {
      if (_latestAlertEvent?.type == FocusEventType.faceAbsent) {
        _latestAlertEvent = null;
      }
      notifyListeners();
    }
  }

  void dismissLatestAlert() {
    _latestAlertEvent = null;
    notifyListeners();
  }

  /// Ingest real-time camera computer vision observation directly into focus engine
  void ingestObservation(FocusObservation observation) {
    if (_state != SessionState.active) return;

    final now = observation.timestamp;
    if (_lastObservationTime != null) {
      final delta = (now.difference(_lastObservationTime!).inMilliseconds / 1000.0).clamp(0.0, 3.0);
      _totalObservedSeconds += delta;

      if (!observation.isFaceDetected) {
        _awaySeconds += delta;
      } else if (observation.phoneDetected) {
        _phoneDetectedSeconds += delta;
      } else if (observation.eyeState == EyeState.closed || (observation.ear != null && observation.ear! < 0.20)) {
        _eyesClosedSeconds += delta;
      } else if (observation.isDistractionDetected || observation.distractionType != null) {
        _lookingAwaySeconds += delta;
      } else {
        _focusedSeconds += delta;
      }

      _recalculateFocusScore();
    }
    _lastObservationTime = now;

    if (focusMonitoringService != null) {
      focusMonitoringService!.ingestObservation(observation);
    }
    notifyListeners();
  }

  void _recalculateFocusScore() {
    if (_totalObservedSeconds > 0) {
      final ratio = _focusedSeconds / _totalObservedSeconds;
      _focusScore = (ratio * 100).round().clamp(0, 100);
    } else if (_distractionsCount > 0) {
      // In synthetic tests or without camera observations, deduce from recorded distractions
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
    _focusedSeconds = 0.0;
    _awaySeconds = 0.0;
    _lookingAwaySeconds = 0.0;
    _eyesClosedSeconds = 0.0;
    _phoneDetectedSeconds = 0.0;
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

    // Start CV Monitoring pipeline
    focusMonitoringService?.start();

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
    _state = SessionState.paused;

    // Pause CV Monitoring pipeline
    focusMonitoringService?.pause();

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
    _state = SessionState.active;

    _startTicker();

    // Resume CV Monitoring pipeline
    focusMonitoringService?.resume();

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
    _finalElapsedSeconds = _accumulatedActiveSeconds;

    // Stop CV Monitoring pipeline
    focusMonitoringService?.stop();

    _recalculateFocusScore();

    _state = SessionState.completed;
    notifyListeners();
    return true;
  }

  void setReflection(SessionReflection reflection) {
    _selectedReflection = reflection;
    notifyListeners();
  }

  /// Idempotently save completed study session to backend.
  Future<StudySessionRecord?> saveCompletedSession() async {
    if (_state != SessionState.completed || _isSaving) {
      return _lastSavedRecord;
    }

    _isSaving = true;
    notifyListeners();

    try {
      final durationMins = max(1, (_finalElapsedSeconds / 60).round());
      final record = StudySessionRecord(
        id: 'sess_${DateTime.now().millisecondsSinceEpoch}',
        subjectId: _currentConfig?.subjectId,
        topicId: _currentConfig?.topicId,
        subjectTitle: _currentConfig?.subjectTitle ?? 'General Study',
        topicTitle: _currentConfig?.topicTitle ?? 'Focused Session',
        durationMinutes: durationMins,
        focusScore: _focusScore,
        distractionsCount: _distractionsCount,
        completedAt: _completedAt ?? DateTime.now(),
        reflection: _selectedReflection,
      );

      if (sessionRepository != null) {
        await sessionRepository!.saveSession(record);
      }

      _lastSavedRecord = record;
      _state = SessionState.idle;
      _isSaving = false;
      notifyListeners();
      return record;
    } catch (_) {
      _isSaving = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Cancel/abort session and return to idle.
  void cancelSession() {
    _ticker?.cancel();
    focusMonitoringService?.stop();
    _state = SessionState.idle;
    _currentConfig = null;
    _sessionStartTime = null;
    _currentSegmentStartTime = null;
    _pausedAt = null;
    _completedAt = null;
    _accumulatedActiveSeconds = 0;
    _finalElapsedSeconds = 0;
    _latestAlertEvent = null;
    _isSaving = false;
    notifyListeners();
  }

  /// Telemetry hook for recorded distractions.
  void recordDistraction({String? category}) {
    if (_state == SessionState.active) {
      _distractionsCount++;
      _recalculateFocusScore();
      notifyListeners();
    }
  }

  /// Legacy helper for mock tests.
  void recordMockDistraction() {
    recordDistraction();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == SessionState.active) {
        if (elapsedSeconds >= _targetSeconds && _targetSeconds > 0) {
          endSession();
        } else {
          notifyListeners();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _state == SessionState.active) {
      if (elapsedSeconds >= _targetSeconds && _targetSeconds > 0) {
        endSession();
      } else {
        notifyListeners();
      }
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
