class GoalMilestone {
  const GoalMilestone({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final bool isCompleted;

  GoalMilestone copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return GoalMilestone(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class GoalModel {
  const GoalModel({
    required this.id,
    required this.title,
    required this.subjectTitle,
    required this.targetDate,
    this.milestones = const [],
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final String subjectTitle;
  final DateTime targetDate;
  final List<GoalMilestone> milestones;
  final bool isCompleted;

  double get progress {
    if (isCompleted) return 1.0;
    if (milestones.isEmpty) return 0.0;
    final done = milestones.where((m) => m.isCompleted).length;
    return (done / milestones.length).clamp(0.0, 1.0);
  }

  GoalModel copyWith({
    String? id,
    String? title,
    String? subjectTitle,
    DateTime? targetDate,
    List<GoalMilestone>? milestones,
    bool? isCompleted,
  }) {
    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subjectTitle: subjectTitle ?? this.subjectTitle,
      targetDate: targetDate ?? this.targetDate,
      milestones: milestones ?? this.milestones,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
