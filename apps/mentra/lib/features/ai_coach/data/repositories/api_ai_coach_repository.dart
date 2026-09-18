import '../../../../core/network/api_client.dart';
import '../../domain/models/coach_insight.dart';
import '../../domain/repositories/ai_coach_repository.dart';
import 'mock_ai_coach_repository.dart';

class ApiAiCoachRepository implements AiCoachRepository {
  ApiAiCoachRepository({
    required this.apiClient,
    AiCoachRepository? fallbackRepository,
  }) : _fallback = fallbackRepository ?? MockAiCoachRepository();

  final ApiClient apiClient;
  final AiCoachRepository _fallback;

  @override
  Future<List<CoachInsightModel>> getCoachInsights() async {
    try {
      final res = await apiClient.get('/api/v1/ai-coach/insights');
      if (res is List) {
        return res.map((item) {
          final m = item as Map<String, dynamic>;
          return CoachInsightModel(
            id: m['id'] as String? ?? 'ins_1',
            title: m['title'] as String? ?? 'Study Insight',
            category: (m['category'] as String? ?? 'Focus').toUpperCase(),
            summary: m['summary'] as String? ?? '',
            actionRecommendation: m['action_recommendation'] as String? ?? '',
            impactMetric: m['impact_metric'] as String? ?? '+10% Focus',
          );
        }).toList();
      }
    } catch (_) {
      // Fallback gracefully on network error
    }
    return _fallback.getCoachInsights();
  }

  @override
  Future<List<ChatMessage>> getInitialChatHistory() async {
    try {
      final res = await apiClient.get('/api/v1/ai-coach/chat');
      if (res is List && res.isNotEmpty) {
        return res.map((item) {
          final m = item as Map<String, dynamic>;
          return ChatMessage(
            id: m['id'] as String? ?? 'msg_1',
            sender: m['sender'] as String? ?? 'coach',
            text: m['message'] as String? ?? '',
            timestamp: m['timestamp'] != null
                ? DateTime.tryParse(m['timestamp'].toString()) ?? DateTime.now()
                : DateTime.now(),
          );
        }).toList();
      }
      return [];
    } catch (_) {
      // Fallback gracefully
    }
    return _fallback.getInitialChatHistory();
  }

  @override
  Future<ChatMessage> askCoachQuestion(
    String question, {
    String? subjectId,
    String? topicId,
    List<ChatMessage>? history,
    String? provider,
    String? apiKey,
    String? model,
    String? customSystemPrompt,
    String? customEndpointUrl,
  }) async {
    try {
      final historyPayload = (history ?? []).map((h) {
        return {
          'role': h.sender == 'user' ? 'user' : 'assistant',
          'content': h.text,
        };
      }).toList();

      final res = await apiClient.post(
        '/api/v1/ai-coach/chat',
        body: {
          'message': question,
          'history': historyPayload,
          'subject_id': subjectId,
          'topic_id': topicId,
          'include_study_context': true,
          if (provider != null) ...{'provider': provider},
          if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
          if (model != null && model.isNotEmpty) 'model': model,
          if (customSystemPrompt != null && customSystemPrompt.isNotEmpty) 'custom_system_prompt': customSystemPrompt,
          if (customEndpointUrl != null && customEndpointUrl.isNotEmpty) 'custom_endpoint_url': customEndpointUrl,
        },
      );
      if (res is Map<String, dynamic>) {
        return ChatMessage(
          id: res['id'] as String? ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
          sender: res['sender'] as String? ?? 'coach',
          text: res['message'] as String? ?? '',
          timestamp: res['timestamp'] != null
              ? DateTime.tryParse(res['timestamp'].toString()) ?? DateTime.now()
              : DateTime.now(),
        );
      }
    } catch (_) {
      // Fallback gracefully
    }
    return _fallback.askCoachQuestion(
      question,
      subjectId: subjectId,
      topicId: topicId,
      history: history,
      provider: provider,
      apiKey: apiKey,
      model: model,
      customSystemPrompt: customSystemPrompt,
      customEndpointUrl: customEndpointUrl,
    );
  }

  @override
  Future<Map<String, dynamic>> explainConcept(
    String conceptName, {
    String? subjectId,
    String? topicId,
    String? difficultyLevel,
  }) async {
    try {
      final res = await apiClient.post(
        '/api/v1/ai-coach/explain',
        body: {
          'concept_name': conceptName,
          'subject_id': subjectId,
          'topic_id': topicId,
          'difficulty_level': difficultyLevel ?? 'intermediate',
        },
      );
      if (res is Map<String, dynamic>) {
        return res;
      }
    } catch (_) {
      // Fallback
    }
    return _fallback.explainConcept(
      conceptName,
      subjectId: subjectId,
      topicId: topicId,
      difficultyLevel: difficultyLevel,
    );
  }

  @override
  Future<Map<String, dynamic>> evaluateIntervention({
    required String subjectTitle,
    required String topicTitle,
    required int elapsedMinutes,
    required int distractionsCount,
    required String triggerReason,
  }) async {
    try {
      final res = await apiClient.post(
        '/api/v1/ai-coach/intervention',
        body: {
          'subject_title': subjectTitle,
          'topic_title': topicTitle,
          'elapsed_minutes': elapsedMinutes,
          'distractions_count': distractionsCount,
          'trigger_reason': triggerReason,
        },
      );
      if (res is Map<String, dynamic>) {
        return res;
      }
    } catch (_) {
      // Fallback
    }
    return _fallback.evaluateIntervention(
      subjectTitle: subjectTitle,
      topicTitle: topicTitle,
      elapsedMinutes: elapsedMinutes,
      distractionsCount: distractionsCount,
      triggerReason: triggerReason,
    );
  }

  @override
  Future<Map<String, dynamic>> analyzeSession({
    required String sessionId,
    required String subjectTitle,
    required String topicTitle,
    required int actualDurationMinutes,
    required int targetDurationMinutes,
    required int focusScore,
    required int distractionsCount,
    required String reflection,
  }) async {
    try {
      final res = await apiClient.post(
        '/api/v1/ai-coach/session-analysis',
        body: {
          'session_id': sessionId,
          'subject_title': subjectTitle,
          'topic_title': topicTitle,
          'actual_duration_minutes': actualDurationMinutes,
          'target_duration_minutes': targetDurationMinutes,
          'focus_score': focusScore,
          'distractions_count': distractionsCount,
          'reflection': reflection,
        },
      );
      if (res is Map<String, dynamic>) {
        return res;
      }
    } catch (_) {
      // Fallback
    }
    return _fallback.analyzeSession(
      sessionId: sessionId,
      subjectTitle: subjectTitle,
      topicTitle: topicTitle,
      actualDurationMinutes: actualDurationMinutes,
      targetDurationMinutes: targetDurationMinutes,
      focusScore: focusScore,
      distractionsCount: distractionsCount,
      reflection: reflection,
    );
  }
}
