class SessionConfig {
  const SessionConfig({
    required this.subjectId,
    required this.subjectTitle,
    required this.topicId,
    required this.topicTitle,
    this.targetDurationMinutes = 45,
    this.studyMode = 'Focus Mode',
    this.isFocusMonitoringEnabled = true,
  });

  final String subjectId;
  final String subjectTitle;
  final String topicId;
  final String topicTitle;
  final int targetDurationMinutes;
  final String studyMode;
  final bool isFocusMonitoringEnabled;
}
