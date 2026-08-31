class CoachingInsightItem {
  const CoachingInsightItem({
    required this.title,
    required this.description,
    required this.category,
    required this.iconName,
  });

  final String title;
  final String description;
  final String category;
  final String iconName;
}

class MockAiCoachData {
  static const String introDescription =
      'Mentra analyzes your focus telemetry, drowsiness cues, and study patterns to provide tailored recommendations for optimal learning retention.';

  static const String recentInsightTitle = 'Morning Peak Focus';
  static const String recentInsightBody =
      'Your AI coaching insights will appear after completing study sessions. Based on your initial sessions, your attention retention is highest between 09:00 AM and 11:30 AM.';

  static const List<CoachingInsightItem> habitSuggestions = [
    CoachingInsightItem(
      title: 'Optimal Interval: 45 / 10',
      description: 'Your sustained attention begins dropping slightly after 42 minutes. We recommend a 10-minute restorative break.',
      category: 'Focus Optimization',
      iconName: 'timer',
    ),
    CoachingInsightItem(
      title: 'Evening Fatigue Management',
      description: 'Mild eye fatigue was detected during late-afternoon sessions. Consider adjusting ambient desk lighting.',
      category: 'Ergonomics & Fatigue',
      iconName: 'visibility',
    ),
    CoachingInsightItem(
      title: 'Deep Work Consistency',
      description: 'You maintained an 84% focus score across Data Analytics units. Good progress toward weekly mastery.',
      category: 'Milestone Coaching',
      iconName: 'psychology',
    ),
  ];
}
