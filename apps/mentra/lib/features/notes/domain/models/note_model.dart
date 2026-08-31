class NoteModel {
  const NoteModel({
    required this.id,
    required this.subjectId,
    required this.subjectTitle,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.tags = const [],
  });

  final String id;
  final String subjectId;
  final String subjectTitle;
  final String title;
  final String content;
  final DateTime updatedAt;
  final List<String> tags;

  int get wordCount {
    if (content.trim().isEmpty) return 0;
    return content.trim().split(RegExp(r'\s+')).length;
  }

  NoteModel copyWith({
    String? id,
    String? subjectId,
    String? subjectTitle,
    String? title,
    String? content,
    DateTime? updatedAt,
    List<String>? tags,
  }) {
    return NoteModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      subjectTitle: subjectTitle ?? this.subjectTitle,
      title: title ?? this.title,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
    );
  }
}
