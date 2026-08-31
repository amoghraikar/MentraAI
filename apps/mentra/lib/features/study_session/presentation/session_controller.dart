import 'dart:async';
import 'package:flutter/material.dart';
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

class SessionController extends ChangeNotifier {
  SessionController({this.sessionRepository});

  final SessionRepository? sessionRepository;

  SessionState _state = SessionState.idle;
  SessionConfig? _currentConfig;
  Timer? _timer;

  int _targetSeconds = 0;
  int _elapsedSeconds = 0;
  int _distractionsCount = 0;
  int _focusScore = 88;
  SessionReflection _selectedReflection = SessionReflection.good;
  StudySessionRecord? _lastSavedRecord;

  SessionState get state => _state;
  SessionConfig? get currentConfig => _currentConfig;
  int get targetSeconds => _targetSeconds;
  int get elapsedSeconds => _elapsedSeconds;
  int get remainingSeconds => (_targetSeconds - _elapsedSeconds).clamp(0, _targetSeconds);
  int get distractionsCount => _distractionsCount;
  int get focusScore => _focusScore;
  SessionReflection get selectedReflection => _selectedReflection;
  StudySessionRecord? get lastSavedRecord => _lastSavedRecord;

  double get progressRatio {
    if (_targetSeconds == 0) return 0.0;
    return (_elapsedSeconds / _targetSeconds).clamp(0.0, 1.0);
  }

  String get formattedRemainingTime {
    final s = remainingSeconds;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String get formattedElapsedTime {
    final m = _elapsedSeconds ~/ 60;
    final sec = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  void setupSession(SessionConfig config) {
    _currentConfig = config;
    _targetSeconds = config.targetDurationMinutes * 60;
    _elapsedSeconds = 0;
    _distractionsCount = 0;
    _focusScore = 88;
    _state = SessionState.preparing;
    notifyListeners();
  }

  void startActiveSession() {
    _state = SessionState.active;
    _startTimer();
    notifyListeners();
  }

  void pauseSession() {
    if (_state == SessionState.active) {
      _timer?.cancel();
      _state = SessionState.paused;
      notifyListeners();
    }
  }

  void resumeSession() {
    if (_state == SessionState.paused) {
      _state = SessionState.active;
      _startTimer();
      notifyListeners();
    }
  }

  void endSession() {
    _timer?.cancel();
    // Compute focus score based on distractions and duration
    final durationMins = (_elapsedSeconds / 60).ceil();
    if (durationMins > 0) {
      _focusScore = (92 - (_distractionsCount * 3)).clamp(60, 98);
    }
    _state = SessionState.completed;
    notifyListeners();
  }

  void setReflection(SessionReflection reflection) {
    _selectedReflection = reflection;
    notifyListeners();
  }

  Future<StudySessionRecord> saveCompletedSession() async {
    final durationMins = max(1, (_elapsedSeconds / 60).round());
    final record = StudySessionRecord(
      id: 'sess_${DateTime.now().millisecondsSinceEpoch}',
      subjectTitle: _currentConfig?.subjectTitle ?? 'General Study',
      topicTitle: _currentConfig?.topicTitle ?? 'Focused Session',
      durationMinutes: durationMins,
      focusScore: _focusScore,
      distractionsCount: _distractionsCount,
      completedAt: DateTime.now(),
      reflection: _selectedReflection,
    );

    if (sessionRepository != null) {
      await sessionRepository!.saveSession(record);
    }

    _lastSavedRecord = record;
    _state = SessionState.idle;
    notifyListeners();
    return record;
  }

  void cancelSession() {
    _timer?.cancel();
    _state = SessionState.idle;
    _currentConfig = null;
    notifyListeners();
  }

  void recordMockDistraction() {
    _distractionsCount++;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      if (_elapsedSeconds >= _targetSeconds) {
        endSession();
      } else {
        notifyListeners();
      }
    });
  }

  int max(int a, int b) => a > b ? a : b;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
