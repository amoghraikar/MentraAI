import '../../../../core/network/api_client.dart';
import '../../domain/models/goal_model.dart';
import '../../domain/repositories/goal_repository.dart';

class ApiGoalRepository implements GoalRepository {
  ApiGoalRepository({required this.apiClient});

  final ApiClient apiClient;
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

    // Create a default General Study subject if none exists
    try {
      final newSub = await apiClient.post(
        '/api/v1/subjects',
        body: {
          'title': 'General Study',
          'code': 'GEN-101',
          'description': 'General study goals',
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
  Future<List<GoalModel>> getGoals() async {
    final response = await apiClient.get('/api/v1/goals');
    final list = response as List<dynamic>;
    return list.map((json) => _goalFromJson(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<GoalModel> createGoal({
    required String title,
    required String subjectTitle,
    required DateTime targetDate,
    List<String> milestoneTitles = const [],
  }) async {
    final subjectId = await _getDefaultSubjectId();
    final milestonesPayload = milestoneTitles
        .map((m) => {'title': m, 'is_completed': false})
        .toList();

    final response = await apiClient.post(
      '/api/v1/goals',
      body: {
        'subject_id': subjectId,
        'title': title,
        'target_date': targetDate.toUtc().toIso8601String(),
        'is_completed': false,
        'milestones': milestonesPayload,
      },
    );
    final goal = _goalFromJson(response as Map<String, dynamic>);
    return goal.copyWith(subjectTitle: subjectTitle);
  }

  @override
  Future<GoalModel> updateGoal(GoalModel goal) async {
    final response = await apiClient.put(
      '/api/v1/goals/${goal.id}',
      body: {
        'title': goal.title,
        'target_date': goal.targetDate.toUtc().toIso8601String(),
        'is_completed': goal.isCompleted,
      },
    );
    final updated = _goalFromJson(response as Map<String, dynamic>);
    return updated.copyWith(
      subjectTitle: goal.subjectTitle,
      milestones: goal.milestones,
    );
  }

  @override
  Future<GoalModel> toggleMilestone(String goalId, String milestoneId) async {
    await apiClient.post('/api/v1/goals/$goalId/milestones/$milestoneId/toggle');
    final response = await apiClient.get('/api/v1/goals/$goalId');
    return _goalFromJson(response as Map<String, dynamic>);
  }

  @override
  Future<void> deleteGoal(String id) async {
    await apiClient.delete('/api/v1/goals/$id');
  }

  GoalModel _goalFromJson(Map<String, dynamic> json) {
    final rawMilestones = json['milestones'] as List<dynamic>? ?? [];
    final milestones = rawMilestones.map((m) {
      final map = m as Map<String, dynamic>;
      return GoalMilestone(
        id: map['id'] as String,
        title: map['title'] as String,
        isCompleted: map['is_completed'] as bool? ?? false,
      );
    }).toList();

    final targetDateStr = json['target_date'] as String?;
    final targetDate = targetDateStr != null
        ? DateTime.tryParse(targetDateStr)?.toLocal() ?? DateTime.now()
        : DateTime.now();

    return GoalModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subjectTitle: json['subject_title'] as String? ?? 'General Study',
      targetDate: targetDate,
      milestones: milestones,
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }
}
