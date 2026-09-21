import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../domain/models/coach_insight.dart';
import '../../domain/repositories/ai_coach_repository.dart';
import 'mock_ai_coach_repository.dart';

class ApiAiCoachRepository implements AiCoachRepository {
  ApiAiCoachRepository({
    required this.apiClient,
    AiCoachRepository? fallbackRepository,
  }) : _fallbackRepository = fallbackRepository ?? MockAiCoachRepository();

  final ApiClient apiClient;
  final AiCoachRepository _fallbackRepository;

  @override
  Future<List<CoachInsightModel>> getCoachInsights() async {
    try {
      final res = await apiClient.get('/api/v1/ai-coach/insights');
      if (res is List && res.isNotEmpty) {
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
      // Network error, fall through to fallback
    }
    return _fallbackRepository.getCoachInsights();
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
    } catch (_) {
      // Network error, fall through to fallback
    }
    return _fallbackRepository.getInitialChatHistory();
  }

  @override
  Future<ChatMessage> askCoachQuestion(
    String question, {
    String? subjectId,
    String? topicId,
    String? subjectTitle,
    String? topicTitle,
    String? studyGoal,
    int? elapsedMinutes,
    int? targetDurationMinutes,
    bool? isSessionActive,
    int? focusScore,
    List<ChatMessage>? history,
    String? provider,
    String? apiKey,
    String? model,
    String? customSystemPrompt,
    String? customEndpointUrl,
    String? attachedMaterialText,
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
          'subject_title': ?subjectTitle,
          'topic_title': ?topicTitle,
          'study_goal': ?studyGoal,
          'elapsed_minutes': ?elapsedMinutes,
          'target_duration_minutes': ?targetDurationMinutes,
          'is_session_active': ?isSessionActive,
          'focus_score': ?focusScore,
          'include_study_context': true,
          if (provider != null) ...{'provider': provider},
          if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
          if (model != null && model.isNotEmpty) 'model': model,
          if (customSystemPrompt != null && customSystemPrompt.isNotEmpty) 'custom_system_prompt': customSystemPrompt,
          if (customEndpointUrl != null && customEndpointUrl.isNotEmpty) 'custom_endpoint_url': customEndpointUrl,
          if (attachedMaterialText != null && attachedMaterialText.isNotEmpty) 'attached_material_text': attachedMaterialText,
        },
      );
      if (res is Map<String, dynamic>) {
        final text = res['message'] as String? ?? '';
        if (text.isNotEmpty && !text.contains("couldn't generate a response")) {
          return ChatMessage(
            id: res['id'] as String? ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
            sender: res['sender'] as String? ?? 'coach',
            text: text,
            timestamp: res['timestamp'] != null
                ? DateTime.tryParse(res['timestamp'].toString()) ?? DateTime.now()
                : DateTime.now(),
          );
        }
      }
    } catch (_) {
      // Offline or network error: return honest message
    }

    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'coach',
      text: "Mentra's local model isn't available right now. Please ensure the local AI service is running.",
      timestamp: DateTime.now(),
    );
  }

  @override
  Stream<String> streamCoachQuestion(
    String question, {
    String? subjectId,
    String? topicId,
    String? subjectTitle,
    String? topicTitle,
    String? studyGoal,
    int? elapsedMinutes,
    int? targetDurationMinutes,
    bool? isSessionActive,
    int? focusScore,
    List<ChatMessage>? history,
    String? customSystemPrompt,
  }) async* {
    bool receivedAnyChunk = false;
    try {
      final body = <String, dynamic>{
        'message': question,
        'include_study_context': true,
        'history': (history ?? [])
            .map((m) => {
                  'role': m.sender == 'user' ? 'user' : 'assistant',
                  'content': m.text,
                })
            .toList(),
      };
      if (subjectId != null) body['subject_id'] = subjectId;
      if (topicId != null) body['topic_id'] = topicId;
      if (subjectTitle != null) body['subject_title'] = subjectTitle;
      if (topicTitle != null) body['topic_title'] = topicTitle;
      if (studyGoal != null) body['study_goal'] = studyGoal;
      if (elapsedMinutes != null) body['elapsed_minutes'] = elapsedMinutes;
      if (targetDurationMinutes != null) body['target_duration_minutes'] = targetDurationMinutes;
      if (isSessionActive != null) body['is_session_active'] = isSessionActive;
      if (focusScore != null) body['focus_score'] = focusScore;
      if (customSystemPrompt != null && customSystemPrompt.isNotEmpty) {
        body['custom_system_prompt'] = customSystemPrompt;
      }

      final stream = apiClient.postStream(
        '/api/v1/ai-coach/stream',
        body: body,
      );

      String buffer = '';
      await for (final rawChunk in stream) {
        buffer += rawChunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('data: ')) {
            final jsonStr = trimmed.substring(6).trim();
            if (jsonStr.isEmpty) continue;
            try {
              final data = jsonDecode(jsonStr);
              if (data is Map<String, dynamic>) {
                if (data['error'] != null ||
                    (data['message'] != null &&
                        data['message'].toString().contains("couldn't generate a response"))) {
                  throw Exception(data['error'] ?? data['message']);
                }
                final chunk = data['chunk'] as String? ?? '';
                if (chunk.isNotEmpty) {
                  receivedAnyChunk = true;
                  yield chunk;
                }
                if (data['done'] == true) {
                  final fullMsg = data['message'] as String? ?? '';
                  if (!receivedAnyChunk && fullMsg.isNotEmpty) {
                    receivedAnyChunk = true;
                    yield fullMsg;
                  }
                  return;
                }
              }
            } catch (e) {
              if (e is Exception && !e.toString().contains("Format")) {
                rethrow;
              }
            }
          }
        }
      }
    } catch (e) {
      if (!receivedAnyChunk) {
        // Fallback: If streaming channel fails, fetch full response via standard POST
        try {
          final singleRes = await askCoachQuestion(
            question,
            subjectId: subjectId,
            topicId: topicId,
            subjectTitle: subjectTitle,
            topicTitle: topicTitle,
            studyGoal: studyGoal,
            elapsedMinutes: elapsedMinutes,
            targetDurationMinutes: targetDurationMinutes,
            isSessionActive: isSessionActive,
            focusScore: focusScore,
            history: history,
            customSystemPrompt: customSystemPrompt,
          );
          if (singleRes.text.isNotEmpty &&
              !singleRes.text.contains("isn't available right now")) {
            yield singleRes.text;
            return;
          }
        } catch (_) {}

        yield "Mentra's local model isn't available right now. Please ensure the local AI service is running.";
      }
    }
  }

  @override
  Future<Map<String, dynamic>> getModelStatus() async {
    try {
      final res = await apiClient.get('/api/v1/ai-coach/status');
      if (res is Map<String, dynamic>) {
        return res;
      }
    } catch (_) {}
    return {
      'state': 'OFFLINE',
      'model': 'local-llm',
      'status_message': "Mentra's local model isn't available right now.",
      'is_ready': false,
    };
  }

  @override
  Future<void> cancelGeneration() async {
    try {
      await apiClient.post('/api/v1/ai-coach/cancel');
    } catch (_) {}
  }

  @override
  Future<void> clearChatHistory() async {
    try {
      await apiClient.delete('/api/v1/ai-coach/chat');
    } catch (_) {}
  }

  @override
  Future<Map<String, dynamic>> testKey({
    required String provider,
    String? apiKey,
    String? model,
    String? customEndpointUrl,
  }) async {
    try {
      final res = await apiClient.post(
        '/api/v1/ai-coach/test-key',
        body: {
          'provider': provider,
          if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
          if (model != null && model.isNotEmpty) 'model': model,
          if (customEndpointUrl != null && customEndpointUrl.isNotEmpty) 'custom_endpoint_url': customEndpointUrl,
        },
      );
      if (res is Map<String, dynamic>) {
        return res;
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
        'latency_ms': 0,
      };
    }
    return {'success': false, 'message': 'Unknown error occurred while verifying API key'};
  }

  @override
  Future<Map<String, dynamic>> uploadStudyMaterial({
    required String title,
    required String content,
    String? filename,
  }) async {
    try {
      final res = await apiClient.post(
        '/api/v1/ai-coach/upload-material',
        body: {
          'title': title,
          'content': content,
          'filename': filename,
        },
      );
      if (res is Map<String, dynamic>) {
        return res;
      }
    } catch (_) {}
    return {'title': title, 'char_count': content.length, 'chunks_count': 1};
  }

  @override
  Future<List<Map<String, dynamic>>> listStudyMaterials() async {
    try {
      final res = await apiClient.get('/api/v1/ai-coach/materials');
      if (res is List) {
        return res.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    return [];
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
    } catch (_) {}
    return {
      'concept_name': conceptName,
      'summary': 'Concept explanation unavailable.',
      'key_points': [],
      'recommended_duration_minutes': 15,
    };
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
    } catch (_) {}
    return {
      'should_intervene': true,
      'intervention_title': 'Focus Realignment',
      'intervention_message': 'Take a brief pause and refocus on your study material.',
      'suggested_action': 'micro_stretch',
      'cooldown_seconds': 30,
    };
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
    } catch (_) {}
    return {
      'session_id': sessionId,
      'overall_feedback': 'Study block completed.',
      'focus_rating': focusScore >= 85 ? 'Strong' : 'Moderate',
      'what_went_well': [],
      'areas_for_growth': [],
      'recommended_next_action': 'Review notes and plan your next session.',
    };
  }
}
