import '../models/note_model.dart';

abstract class NoteRepository {
  Future<List<NoteModel>> getNotes({String? searchQuery, String? subjectId});
  Future<NoteModel?> getNoteById(String id);
  Future<NoteModel> createNote({
    required String title,
    required String subjectId,
    required String subjectTitle,
    String content = '',
    List<String> tags = const [],
  });
  Future<NoteModel> updateNote(NoteModel note);
  Future<void> deleteNote(String id);
}
