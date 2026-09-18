import '../models/coach_insight.dart';

abstract class AiCoachRepository {
  Future<List<CoachInsightModel>> getCoachInsights();
  Future<List<ChatMessage>> getInitialChatHistory();
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
  });
  Future<Map<String, dynamic>> explainConcept(String conceptName, {String? subjectId, String? topicId, String? difficultyLevel});
  Future<Map<String, dynamic>> evaluateIntervention({
    required String subjectTitle,
    required String topicTitle,
    required int elapsedMinutes,
    required int distractionsCount,
    required String triggerReason,
  });
  Future<Map<String, dynamic>> analyzeSession({
    required String sessionId,
    required String subjectTitle,
    required String topicTitle,
    required int actualDurationMinutes,
    required int targetDurationMinutes,
    required int focusScore,
    required int distractionsCount,
    required String reflection,
  });
}
