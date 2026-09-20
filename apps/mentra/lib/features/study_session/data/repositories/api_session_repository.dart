import '../../../../core/network/api_client.dart';
import '../../domain/models/study_session_record.dart';
import '../../domain/repositories/session_repository.dart';

class ApiSessionRepository implements SessionRepository {
  ApiSessionRepository({
    required this.apiClient,
    this.fallbackRepository,
  });

  final ApiClient apiClient;
  final SessionRepository? fallbackRepository;
  String? _cachedDefaultSubjectId;

  Future<String> _getDefaultSubjectId() async {
    if (_cachedDefaultSubjectId != null) {
      return _cachedDefaultSubjectId!;
    }
    try {
      final res = await apiClient.get('/api/v1/subjects');
      final list = res as List<dynamic>;
      if (list.isNotEmpty) {
        _cachedDefaultSubjectId = list.first['id'] as String;
        return _cachedDefaultSubjectId!;
      }
    } catch (_) {}

    try {
      final newSub = await apiClient.post(
        '/api/v1/subjects',
        body: {
          'title': 'General Study',
          'code': 'GEN-101',
          'description': 'General study sessions',
          'color_hex': '#4F46E5',
          'total_hours': 0.0,
          'target_hours': 20.0,
        },
      );
      _cachedDefaultSubjectId = newSub['id'] as String;
      return _cachedDefaultSubjectId!;
    } catch (_) {
      return 'default';
    }
  }

  @override
  Future<List<StudySessionRecord>> getRecentSessions({int limit = 10}) async {
    try {
      final response = await apiClient.get(
        '/api/v1/sessions',
        queryParams: {'limit': limit.toString()},
      );
      final list = response as List<dynamic>;
      return list.map((json) => _sessionFromJson(json as Map<String, dynamic>)).toList();
    } catch (_) {
      if (fallbackRepository != null) {
        return fallbackRepository!.getRecentSessions(limit: limit);
      }
      rethrow;
    }
  }

  @override
  Future<StudySessionRecord> saveSession(StudySessionRecord session) async {
    try {
      final effectiveSubjectId = (session.subjectId != null && session.subjectId!.isNotEmpty && session.subjectId != 'default')
          ? session.subjectId!
          : await _getDefaultSubjectId();
      final now = session.completedAt.toUtc();
      final started = now.subtract(Duration(minutes: session.durationMinutes));

      final response = await apiClient.post(
        '/api/v1/sessions',
        body: {
          'subject_id': effectiveSubjectId,
          if (session.topicId != null && session.topicId!.isNotEmpty && session.topicId != 'gen_top')
            'topic_id': session.topicId,
          'target_duration_minutes': session.durationMinutes > 0 ? session.durationMinutes : 45,
          'actual_duration_minutes': session.durationMinutes,
          'study_mode': 'Focus Mode',
          'is_focus_monitoring_enabled': true,
          'focus_score': session.focusScore,
          'distractions_count': session.distractionsCount,
          'reflection': session.reflection.name,
          'started_at': started.toIso8601String(),
          'ended_at': now.toIso8601String(),
        },
      );

      final saved = _sessionFromJson(response as Map<String, dynamic>);
      return StudySessionRecord(
        id: saved.id,
        subjectId: effectiveSubjectId,
        topicId: session.topicId,
        subjectTitle: session.subjectTitle,
        topicTitle: session.topicTitle,
        durationMinutes: saved.durationMinutes,
        focusScore: saved.focusScore,
        distractionsCount: saved.distractionsCount,
        completedAt: saved.completedAt,
        reflection: saved.reflection,
      );
    } catch (_) {
      if (fallbackRepository != null) {
        return fallbackRepository!.saveSession(session);
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getSessionStatistics() async {
    try {
      final sessions = await getRecentSessions(limit: 50);
      if (sessions.isEmpty) {
        return {
          'totalMinutes': 0,
          'averageFocusScore': 0,
          'totalDistractions': 0,
          'completedSessionsCount': 0,
        };
      }

      final totalMinutes = sessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
      final totalDistractions = sessions.fold<int>(0, (sum, s) => sum + s.distractionsCount);
      final avgFocus = (sessions.fold<int>(0, (sum, s) => sum + s.focusScore) / sessions.length).round();

      return {
        'totalMinutes': totalMinutes,
        'averageFocusScore': avgFocus,
        'totalDistractions': totalDistractions,
        'completedSessionsCount': sessions.length,
      };
    } catch (_) {
      if (fallbackRepository != null) {
        return fallbackRepository!.getSessionStatistics();
      }
      rethrow;
    }
  }

  StudySessionRecord _sessionFromJson(Map<String, dynamic> json) {
    final reflectionStr = json['reflection'] as String? ?? 'good';
    final reflection = SessionReflection.values.firstWhere(
      (r) => r.name.toLowerCase() == reflectionStr.toLowerCase(),
      orElse: () => SessionReflection.good,
    );

    final endedAtStr = json['ended_at'] as String? ?? json['created_at'] as String?;
    final completedAt = endedAtStr != null
        ? DateTime.tryParse(endedAtStr)?.toLocal() ?? DateTime.now()
        : DateTime.now();

    return StudySessionRecord(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String?,
      topicId: json['topic_id'] as String?,
      subjectTitle: json['subject_title'] as String? ?? 'Subject',
      topicTitle: json['topic_title'] as String? ?? 'Topic',
      durationMinutes: (json['actual_duration_minutes'] as num?)?.toInt() ?? 0,
      focusScore: (json['focus_score'] as num?)?.toInt() ?? 100,
      distractionsCount: (json['distractions_count'] as num?)?.toInt() ?? 0,
      completedAt: completedAt,
      reflection: reflection,
    );
  }
}
