class GoalItem {
  const GoalItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.progress,
    required this.targetDate,
    required this.milestonesCompleted,
    required this.totalMilestones,
  });

  final String id;
  final String title;
  final String subject;
  final double progress;
  final String targetDate;
  final int milestonesCompleted;
  final int totalMilestones;
}

class MockGoalsData {
  static const List<GoalItem> goals = [
    GoalItem(
      id: 'goal-1',
      title: 'Complete Data Analytics Unit II',
      subject: 'Data Analytics',
      progress: 0.78,
      targetDate: 'Friday, Sep 5',
      milestonesCompleted: 7,
      totalMilestones: 9,
    ),
    GoalItem(
      id: 'goal-2',
      title: 'Complete Software Engineering revision',
      subject: 'Software Engineering',
      progress: 0.62,
      targetDate: 'Sunday, Sep 7',
      milestonesCompleted: 5,
      totalMilestones: 8,
    ),
    GoalItem(
      id: 'goal-3',
      title: 'Prepare for Web Programming practical lab',
      subject: 'Web Programming',
      progress: 0.40,
      targetDate: 'Next Tuesday, Sep 9',
      milestonesCompleted: 2,
      totalMilestones: 5,
    ),
  ];
}
