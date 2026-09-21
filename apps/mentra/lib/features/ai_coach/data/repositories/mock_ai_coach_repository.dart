import 'dart:math';
import '../../domain/models/coach_insight.dart';
import '../../domain/repositories/ai_coach_repository.dart';

class MockAiCoachRepository implements AiCoachRepository {
  @override
  Future<List<CoachInsightModel>> getCoachInsights() async {
    return const [
      CoachInsightModel(
        id: 'ins_1',
        title: 'Optimal Focus Block Duration',
        category: 'FOCUS PATTERN',
        summary: 'Your attention scores peak at 89% during the first 45 minutes of morning study sessions, with fatigue onset occurring past minute 55.',
        actionRecommendation: 'Schedule 45 to 50-minute study blocks followed by 10-minute active stretch breaks.',
        impactMetric: '+14% Estimated retention',
      ),
      CoachInsightModel(
        id: 'ins_2',
        title: 'Phone Distraction Suppression',
        category: 'ENVIRONMENT',
        summary: 'Phone pickups accounted for 48% of total distraction events, primarily during conceptual study in Data Analytics.',
        actionRecommendation: 'Place your phone outside immediate visual reach or enable Do Not Disturb before starting sessions.',
        impactMetric: '-35% Distraction frequency',
      ),
      CoachInsightModel(
        id: 'ins_3',
        title: 'Study Consistency Momentum',
        category: 'HABIT LOOP',
        summary: 'You have maintained 5 consecutive active study days this week, scoring an average 84% focus baseline.',
        actionRecommendation: 'Complete one 40-minute revision session today on Software Engineering to solidify your weekly streak.',
        impactMetric: '76% Consistency Index',
      ),
    ];
  }

  @override
  Future<List<ChatMessage>> getInitialChatHistory() async {
    final now = DateTime.now();
    return [
      ChatMessage(
        id: 'msg_1',
        sender: 'coach',
        text: "Good day! I'm Mentra, your AI Study Coach. I have analyzed your recent study sessions. Your focus is strongest in the morning during 45-minute blocks. How can I help with your study plan today?",
        timestamp: now.subtract(const Duration(minutes: 10)),
      ),
    ];
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
    return ChatMessage(
      id: 'msg_${Random().nextInt(999999)}',
      sender: 'coach',
      text: "Mentra's local model isn't available right now. Please ensure the local AI service is running on your machine.",
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
    final reply = await askCoachQuestion(question, history: history);
    final words = reply.text.split(' ');
    for (int i = 0; i < words.length; i++) {
      yield i == 0 ? words[i] : ' ${words[i]}';
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  @override
  Future<Map<String, dynamic>> testKey({
    required String provider,
    String? apiKey,
    String? model,
    String? customEndpointUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'success': true,
      'latency_ms': 120,
      'message': 'Connected to $provider model ${model ?? "default"} successfully.',
      'provider': provider,
      'model': model ?? 'default',
    };
  }

  @override
  Future<Map<String, dynamic>> uploadStudyMaterial({
    required String title,
    required String content,
    String? filename,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return {
      'doc_id': 'doc_mock_1',
      'title': title,
      'filename': filename ?? '$title.txt',
      'char_count': content.length,
      'chunks_count': (content.length / 500).ceil(),
      'summary_preview': content.length > 100 ? content.substring(0, 100) : content,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> listStudyMaterials() async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> explainConcept(
    String conceptName, {
    String? subjectId,
    String? topicId,
    String? difficultyLevel,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {
      'concept_name': conceptName,
      'summary': '$conceptName is a foundational principle in structured problem solving.',
      'key_points': [
        'Core definition and governing equations',
        'Practical implementation constraints',
        'Common edge cases in real-world application',
      ],
      'analogy': 'Like building blocks that form a resilient bridge.',
      'practice_question': 'How does doubling the initial input alter the steady-state output?',
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
    await Future.delayed(const Duration(milliseconds: 150));
    return {
      'should_intervene': true,
      'intervention_title': 'Focus Realignment',
      'intervention_message': 'You have studied for $elapsedMinutes minutes. Take a 30-second breath and refocus on $topicTitle.',
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
    await Future.delayed(const Duration(milliseconds: 250));
    return {
      'session_id': sessionId,
      'overall_feedback': 'Strong focus throughout the $actualDurationMinutes-minute session on $topicTitle.',
      'focus_rating': focusScore >= 85 ? 'Strong' : 'Moderate',
      'what_went_well': [
        'Maintained active attention for $actualDurationMinutes minutes.',
        'Completed targeted focus interval with minimal interruptions.',
      ],
      'areas_for_growth': [
        'Recorded $distractionsCount distraction instances — try clearing desk space next session.',
      ],
      'recommended_next_action': 'Write 3 self-quiz questions to lock in today’s progress.',
    };
  }

  @override
  Future<Map<String, dynamic>> getModelStatus() async {
    return {
      'state': 'OFFLINE',
      'model': 'local-llm',
      'status_message': "Mentra's local model isn't available right now.",
      'is_ready': false,
    };
  }

  @override
  Future<void> cancelGeneration() async {}

  @override
  Future<void> clearChatHistory() async {}
}

