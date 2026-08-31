import '../models/subject_model.dart';
import '../models/topic_model.dart';

abstract class SubjectRepository {
  Future<List<SubjectModel>> getSubjects();
  Future<SubjectModel?> getSubjectById(String id);
  Future<SubjectModel> createSubject({
    required String title,
    required String code,
    required String description,
    required String colorHex,
  });
  Future<SubjectModel> updateSubject(SubjectModel subject);
  Future<void> deleteSubject(String id);
  Future<TopicModel> addTopic({
    required String subjectId,
    required String title,
    required String description,
    List<String> keyConcepts = const [],
  });
  Future<TopicModel> updateTopic(TopicModel topic);
  Future<void> deleteTopic(String subjectId, String topicId);
}
