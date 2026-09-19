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
    String? attachedMaterialText,
  });
  Stream<String> streamCoachQuestion(
    String question, {
    String? subjectId,
    String? topicId,
    List<ChatMessage>? history,
    String? customSystemPrompt,
  });
  Future<Map<String, dynamic>> testKey({
    required String provider,
    String? apiKey,
    String? model,
    String? customEndpointUrl,
  });
  Future<Map<String, dynamic>> uploadStudyMaterial({
    required String title,
    required String content,
    String? filename,
  });
  Future<List<Map<String, dynamic>>> listStudyMaterials();
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
  Future<Map<String, dynamic>> getModelStatus();
  Future<void> cancelGeneration();
  Future<void> clearChatHistory();
}

