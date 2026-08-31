class MockHomeData {
  static const String greeting = 'Good morning';
  static const String focusPrompt = 'Ready to focus?';

  static const String todayStudyTime = '2h 15m';
  static const String todayFocusScore = '84%';
  static const String todaySessionsCount = '3';

  static const continueSubject = ContinueSubjectItem(
    subject: 'Data Analytics',
    topic: 'Correlation & Regression',
    progress: 0.78,
  );

  static const List<RecentSessionItem> recentSessions = [
    RecentSessionItem(
      subject: 'Data Analytics',
      duration: '52 min',
      focusScore: '84%',
      timestamp: 'Today, 09:30 AM',
    ),
    RecentSessionItem(
      subject: 'Software Engineering',
      duration: '45 min',
      focusScore: '81%',
      timestamp: 'Yesterday, 04:15 PM',
    ),
  ];

  static const String dailyInsight =
      'Your strongest focus period was during your first study session.';
}

class ContinueSubjectItem {
  const ContinueSubjectItem({
    required this.subject,
    required this.topic,
    required this.progress,
  });

  final String subject;
  final String topic;
  final double progress;
}

class RecentSessionItem {
  const RecentSessionItem({
    required this.subject,
    required this.duration,
    required this.focusScore,
    required this.timestamp,
  });

  final String subject;
  final String duration;
  final String focusScore;
  final String timestamp;
}
