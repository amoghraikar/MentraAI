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

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject_id': subjectId,
    'subject_title': subjectTitle,
    'title': title,
    'content': content,
    'updated_at': updatedAt.toIso8601String(),
    'tags': tags,
  };

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as List<dynamic>? ?? [];
    final updatedAtStr = json['updated_at'] as String?;
    final updatedAt = updatedAtStr != null
        ? DateTime.tryParse(updatedAtStr)?.toLocal() ?? DateTime.now()
        : DateTime.now();

    return NoteModel(
      id: json['id'] as String? ?? 'note_${DateTime.now().millisecondsSinceEpoch}',
      subjectId: json['subject_id'] as String? ?? 'sub_gen',
      subjectTitle: json['subject_title'] as String? ?? 'Subject',
      title: json['title'] as String? ?? 'Untitled Note',
      content: json['content'] as String? ?? '',
      updatedAt: updatedAt,
      tags: rawTags.map((e) => e.toString()).toList(),
    );
  }
}
