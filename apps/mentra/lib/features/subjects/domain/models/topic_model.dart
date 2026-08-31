class TopicModel {
  const TopicModel({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.description,
    this.progress = 0.0,
    this.totalMinutes = 0,
    this.keyConcepts = const [],
    this.notesSnippet = '',
    this.isCompleted = false,
  });

  final String id;
  final String subjectId;
  final String title;
  final String description;
  final double progress;
  final int totalMinutes;
  final List<String> keyConcepts;
  final String notesSnippet;
  final bool isCompleted;

  TopicModel copyWith({
    String? id,
    String? subjectId,
    String? title,
    String? description,
    double? progress,
    int? totalMinutes,
    List<String>? keyConcepts,
    String? notesSnippet,
    bool? isCompleted,
  }) {
    return TopicModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      description: description ?? this.description,
      progress: progress ?? this.progress,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      keyConcepts: keyConcepts ?? this.keyConcepts,
      notesSnippet: notesSnippet ?? this.notesSnippet,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
