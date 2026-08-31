class MockAnalyticsData {
  static const String overallFocusScore = '84%';
  static const String totalStudyTime = '12h 35m';
  static const String totalSessions = '18';
  static const String totalDistractions = '24';

  static const List<DailyFocusPoint> weeklyTrend = [
    DailyFocusPoint(day: 'Mon', score: 0.82),
    DailyFocusPoint(day: 'Tue', score: 0.88),
    DailyFocusPoint(day: 'Wed', score: 0.79),
    DailyFocusPoint(day: 'Thu', score: 0.85),
    DailyFocusPoint(day: 'Fri', score: 0.84),
    DailyFocusPoint(day: 'Sat', score: 0.90),
    DailyFocusPoint(day: 'Sun', score: 0.84),
  ];

  static const List<SubjectBreakdown> subjectBreakdown = [
    SubjectBreakdown(subject: 'Data Analytics', hours: 5.8, percentage: 0.46),
    SubjectBreakdown(subject: 'Software Engineering', hours: 4.2, percentage: 0.33),
    SubjectBreakdown(subject: 'Web Programming', hours: 2.6, percentage: 0.21),
  ];
}

class DailyFocusPoint {
  const DailyFocusPoint({required this.day, required this.score});
  final String day;
  final double score;
}

class SubjectBreakdown {
  const SubjectBreakdown({
    required this.subject,
    required this.hours,
    required this.percentage,
  });
  final String subject;
  final double hours;
  final double percentage;
}
