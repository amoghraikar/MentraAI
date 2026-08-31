import '../models/study_session_record.dart';

abstract class SessionRepository {
  Future<List<StudySessionRecord>> getRecentSessions({int limit = 10});
  Future<StudySessionRecord> saveSession(StudySessionRecord session);
  Future<Map<String, dynamic>> getSessionStatistics();
}
