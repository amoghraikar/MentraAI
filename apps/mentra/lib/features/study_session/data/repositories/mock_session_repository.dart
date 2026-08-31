import '../../domain/models/study_session_record.dart';
import '../../domain/repositories/session_repository.dart';

class MockSessionRepository implements SessionRepository {
  MockSessionRepository() {
    _initDefaults();
  }

  final List<StudySessionRecord> _sessions = [];

  void _initDefaults() {
    final now = DateTime.now();
    _sessions.addAll([
      StudySessionRecord(
        id: 'sess_1',
        subjectTitle: 'Data Analytics',
        topicTitle: 'Linear & Multiple Regression',
        durationMinutes: 52,
        focusScore: 88,
        distractionsCount: 2,
        completedAt: now.subtract(const Duration(hours: 3)),
        reflection: SessionReflection.excellent,
      ),
      StudySessionRecord(
        id: 'sess_2',
        subjectTitle: 'Software Engineering',
        topicTitle: 'Agile Methodology & Scrum',
        durationMinutes: 45,
        focusScore: 82,
        distractionsCount: 3,
        completedAt: now.subtract(const Duration(days: 1, hours: 2)),
        reflection: SessionReflection.good,
      ),
      StudySessionRecord(
        id: 'sess_3',
        subjectTitle: 'Web Programming',
        topicTitle: 'Modern CSS & Flexbox / Grid',
        durationMinutes: 38,
        focusScore: 78,
        distractionsCount: 4,
        completedAt: now.subtract(const Duration(days: 2, hours: 5)),
        reflection: SessionReflection.okay,
      ),
      StudySessionRecord(
        id: 'sess_4',
        subjectTitle: 'Data Analytics',
        topicTitle: 'Correlation & Covariance',
        durationMinutes: 60,
        focusScore: 91,
        distractionsCount: 1,
        completedAt: now.subtract(const Duration(days: 3, hours: 1)),
        reflection: SessionReflection.excellent,
      ),
    ]);
  }

  @override
  Future<List<StudySessionRecord>> getRecentSessions({int limit = 10}) async {
    return _sessions.take(limit).toList();
  }

  @override
  Future<StudySessionRecord> saveSession(StudySessionRecord session) async {
    _sessions.insert(0, session);
    return session;
  }

  @override
  Future<Map<String, dynamic>> getSessionStatistics() async {
    final totalMins = _sessions.fold<int>(0, (acc, s) => acc + s.durationMinutes);
    final avgFocus = _sessions.isEmpty
        ? 0
        : (_sessions.fold<int>(0, (acc, s) => acc + s.focusScore) / _sessions.length).round();

    final hours = (totalMins / 60).toStringAsFixed(1);

    return {
      'totalStudyHours': '${hours}h',
      'totalMinutes': totalMins,
      'totalSessions': _sessions.length,
      'averageFocus': '$avgFocus%',
      'consistencyScore': '76%',
    };
  }
}
