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
        text: 'Good day! I have analyzed your recent study sessions. Your focus is strongest in the morning during 45-minute blocks. How can I help with your study plan today?',
        timestamp: now.subtract(const Duration(minutes: 10)),
      ),
    ];
  }

  @override
  Future<ChatMessage> askCoachQuestion(String question) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final q = question.toLowerCase();

    String reply;
    if (q.contains('schedule') || q.contains('plan') || q.contains('time')) {
      reply = 'Based on your attention curve, I recommend dedicating 50 minutes to Data Analytics (Regression) first, followed by a 10-minute break, then a 40-minute session on Software Engineering.';
    } else if (q.contains('focus') || q.contains('distraction') || q.contains('phone')) {
      reply = 'To minimize distractions, keep your phone in another room or out of sight. Your analytics show an immediate 18% boost in continuous attention when phone interactions are eliminated.';
    } else if (q.contains('exam') || q.contains('revision') || q.contains('test')) {
      reply = 'For exam preparation, active recall and solving practice problem sets produces 2.5x stronger retention than passive note reading. Try testing yourself on Correlation and OLS formulas.';
    } else {
      reply = 'Great question. To optimize this topic, break it down into key concept checkpoints and run a timed 45-minute focus session with Mentra monitoring.';
    }

    return ChatMessage(
      id: 'msg_${Random().nextInt(999999)}',
      sender: 'coach',
      text: reply,
      timestamp: DateTime.now(),
    );
  }
}
