import '../../../../core/network/api_client.dart';
import '../../domain/models/subject_model.dart';
import '../../domain/models/topic_model.dart';
import '../../domain/repositories/subject_repository.dart';

class ApiSubjectRepository implements SubjectRepository {
  ApiSubjectRepository({
    required this.apiClient,
    this.fallbackRepository,
  });

  final ApiClient apiClient;
  final SubjectRepository? fallbackRepository;
  final List<SubjectModel> _localCache = [];

  @override
  Future<List<SubjectModel>> getSubjects() async {
    try {
      final response = await apiClient.get('/api/v1/subjects');
      final list = response as List<dynamic>;
      final parsed = list.map((json) => _subjectFromJson(json as Map<String, dynamic>)).toList();
      _localCache.clear();
      _localCache.addAll(parsed);
      return parsed;
    } on ApiException {
      if (_localCache.isNotEmpty) {
        return List.unmodifiable(_localCache);
      }
      if (fallbackRepository != null) {
        return fallbackRepository!.getSubjects();
      }
      rethrow;
    } catch (_) {
      if (_localCache.isNotEmpty) {
        return List.unmodifiable(_localCache);
      }
      if (fallbackRepository != null) {
        return fallbackRepository!.getSubjects();
      }
      rethrow;
    }
  }

  @override
  Future<SubjectModel?> getSubjectById(String id) async {
    try {
      final response = await apiClient.get('/api/v1/subjects/$id');
      final sub = _subjectFromJson(response as Map<String, dynamic>);
      final idx = _localCache.indexWhere((s) => s.id == id);
      if (idx != -1) {
        _localCache[idx] = sub;
      } else {
        _localCache.add(sub);
      }
      return sub;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      final cached = _localCache.where((s) => s.id == id).firstOrNull;
      if (cached != null) return cached;
      if (fallbackRepository != null) {
        return fallbackRepository!.getSubjectById(id);
      }
      rethrow;
    } catch (_) {
      final cached = _localCache.where((s) => s.id == id).firstOrNull;
      if (cached != null) return cached;
      if (fallbackRepository != null) {
        return fallbackRepository!.getSubjectById(id);
      }
      rethrow;
    }
  }

  @override
  Future<SubjectModel> createSubject({
    required String title,
    required String code,
    required String description,
    required String colorHex,
  }) async {
    try {
      final response = await apiClient.post(
        '/api/v1/subjects',
        body: {
          'title': title,
          'code': code,
          'description': description,
          'color_hex': colorHex,
          'total_hours': 0.0,
          'target_hours': 20.0,
        },
      );
      final created = _subjectFromJson(response as Map<String, dynamic>);
      _localCache.insert(0, created);
      return created;
    } on ApiException {
      rethrow;
    } catch (_) {
      final fallback = SubjectModel(
        id: 'sub_local_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        code: code,
        description: description,
        colorHex: colorHex,
        totalHours: 0.0,
        targetHours: 20.0,
        topics: [],
      );
      _localCache.insert(0, fallback);
      return fallback;
    }
  }

  @override
  Future<SubjectModel> updateSubject(SubjectModel subject) async {
    try {
      final response = await apiClient.put(
        '/api/v1/subjects/${subject.id}',
        body: {
          'title': subject.title,
          'code': subject.code,
          'description': subject.description,
          'color_hex': subject.colorHex,
          'total_hours': subject.totalHours,
          'target_hours': subject.targetHours,
        },
      );
      final updated = _subjectFromJson(response as Map<String, dynamic>);
      final res = updated.copyWith(topics: subject.topics);
      final idx = _localCache.indexWhere((s) => s.id == subject.id);
      if (idx != -1) _localCache[idx] = res;
      return res;
    } catch (_) {
      final idx = _localCache.indexWhere((s) => s.id == subject.id);
      if (idx != -1) _localCache[idx] = subject;
      return subject;
    }
  }

  @override
  Future<void> deleteSubject(String id) async {
    _localCache.removeWhere((s) => s.id == id);
    try {
      await apiClient.delete('/api/v1/subjects/$id');
    } catch (_) {}
  }

  @override
  Future<TopicModel> addTopic({
    required String subjectId,
    required String title,
    required String description,
    List<String> keyConcepts = const [],
  }) async {
    final response = await apiClient.post(
      '/api/v1/topics',
      body: {
        'subject_id': subjectId,
        'title': title,
        'description': description,
        'key_concepts': keyConcepts,
        'progress': 0.0,
        'total_minutes': 0,
        'notes_snippet': '',
        'is_completed': false,
      },
    );
    return _topicFromJson(response as Map<String, dynamic>);
  }

  @override
  Future<TopicModel> updateTopic(TopicModel topic) async {
    final response = await apiClient.put(
      '/api/v1/topics/${topic.id}',
      body: {
        'title': topic.title,
        'description': topic.description,
        'progress': topic.progress,
        'total_minutes': topic.totalMinutes,
        'key_concepts': topic.keyConcepts,
        'notes_snippet': topic.notesSnippet,
        'is_completed': topic.isCompleted,
      },
    );
    return _topicFromJson(response as Map<String, dynamic>);
  }

  @override
  Future<void> deleteTopic(String subjectId, String topicId) async {
    await apiClient.delete('/api/v1/topics/$topicId');
  }

  SubjectModel _subjectFromJson(Map<String, dynamic> json) {
    final rawTopics = json['topics'] as List<dynamic>? ?? [];
    final topics = rawTopics
        .map((t) => _topicFromJson(t as Map<String, dynamic>))
        .toList();

    return SubjectModel(
      id: json['id'] as String,
      title: json['title'] as String,
      code: json['code'] as String,
      description: json['description'] as String? ?? '',
      colorHex: json['color_hex'] as String? ?? '#4F46E5',
      totalHours: (json['total_hours'] as num?)?.toDouble() ?? 0.0,
      targetHours: (json['target_hours'] as num?)?.toDouble() ?? 20.0,
      topics: topics,
    );
  }

  TopicModel _topicFromJson(Map<String, dynamic> json) {
    final rawConcepts = json['key_concepts'] as List<dynamic>? ?? [];
    return TopicModel(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
      keyConcepts: rawConcepts.map((e) => e.toString()).toList(),
      notesSnippet: json['notes_snippet'] as String? ?? '',
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }
}
