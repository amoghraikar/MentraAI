enum SessionReflection {
  difficult,
  okay,
  good,
  excellent,
}

class StudySessionRecord {
  const StudySessionRecord({
    required this.id,
    this.subjectId,
    this.topicId,
    required this.subjectTitle,
    required this.topicTitle,
    required this.durationMinutes,
    required this.focusScore,
    required this.distractionsCount,
    required this.completedAt,
    this.reflection = SessionReflection.good,
  });

  final String id;
  final String? subjectId;
  final String? topicId;
  final String subjectTitle;
  final String topicTitle;
  final int durationMinutes;
  final int focusScore; // Percentage 0-100
  final int distractionsCount;
  final DateTime completedAt;
  final SessionReflection reflection;
}
