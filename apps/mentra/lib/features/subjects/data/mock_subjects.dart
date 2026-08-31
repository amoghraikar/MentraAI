class SubjectItem {
  const SubjectItem({
    required this.id,
    required this.title,
    required this.description,
    required this.topics,
    required this.progress,
    required this.totalSessions,
    required this.totalHours,
  });

  final String id;
  final String title;
  final String description;
  final List<String> topics;
  final double progress;
  final int totalSessions;
  final double totalHours;
}

class MockSubjectsData {
  static const List<SubjectItem> subjects = [
    SubjectItem(
      id: 'sub-1',
      title: 'Data Analytics',
      description: 'Statistical methods, descriptive statistics, and regression models',
      topics: ['Correlation & Regression', 'Probability Distributions', 'Hypothesis Testing'],
      progress: 0.78,
      totalSessions: 14,
      totalHours: 18.5,
    ),
    SubjectItem(
      id: 'sub-2',
      title: 'Software Engineering',
      description: 'Development methodologies, architecture patterns, and agile workflows',
      topics: ['Agile', 'Scrum', 'XP', 'CI/CD Pipelines'],
      progress: 0.64,
      totalSessions: 9,
      totalHours: 12.0,
    ),
    SubjectItem(
      id: 'sub-3',
      title: 'Web Programming',
      description: 'Frontend fundamentals, responsive interfaces, and client-side logic',
      topics: ['HTML', 'CSS', 'DOM API', 'Modern JavaScript'],
      progress: 0.42,
      totalSessions: 6,
      totalHours: 7.5,
    ),
  ];
}
