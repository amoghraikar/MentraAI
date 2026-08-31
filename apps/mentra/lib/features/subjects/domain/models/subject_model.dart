import 'topic_model.dart';

class SubjectModel {
  const SubjectModel({
    required this.id,
    required this.title,
    required this.code,
    required this.description,
    required this.colorHex,
    this.topics = const [],
    this.totalHours = 0.0,
    this.targetHours = 20.0,
  });

  final String id;
  final String title;
  final String code;
  final String description;
  final String colorHex;
  final List<TopicModel> topics;
  final double totalHours;
  final double targetHours;

  double get overallProgress {
    if (topics.isEmpty) return 0.0;
    final sum = topics.fold<double>(0.0, (acc, t) => acc + t.progress);
    return (sum / topics.length).clamp(0.0, 1.0);
  }

  int get completedTopicsCount => topics.where((t) => t.isCompleted || t.progress >= 1.0).length;

  SubjectModel copyWith({
    String? id,
    String? title,
    String? code,
    String? description,
    String? colorHex,
    List<TopicModel>? topics,
    double? totalHours,
    double? targetHours,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      code: code ?? this.code,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      topics: topics ?? this.topics,
      totalHours: totalHours ?? this.totalHours,
      targetHours: targetHours ?? this.targetHours,
    );
  }
}
