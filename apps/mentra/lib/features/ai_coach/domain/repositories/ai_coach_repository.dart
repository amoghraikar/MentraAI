import '../models/coach_insight.dart';

abstract class AiCoachRepository {
  Future<List<CoachInsightModel>> getCoachInsights();
  Future<List<ChatMessage>> getInitialChatHistory();
  Future<ChatMessage> askCoachQuestion(String question);
}
