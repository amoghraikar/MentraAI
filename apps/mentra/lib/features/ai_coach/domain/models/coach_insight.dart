class CoachInsightModel {
  const CoachInsightModel({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.actionRecommendation,
    required this.impactMetric,
  });

  final String id;
  final String title;
  final String category;
  final String summary;
  final String actionRecommendation;
  final String impactMetric;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender, // 'user' or 'coach'
    required this.text,
    required this.timestamp,
  });

  final String id;
  final String sender;
  final String text;
  final DateTime timestamp;
}
