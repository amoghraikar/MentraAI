import '../../../../core/network/api_client.dart';
import '../../domain/models/note_model.dart';
import '../../domain/repositories/note_repository.dart';

class ApiNoteRepository implements NoteRepository {
  ApiNoteRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<NoteModel>> getNotes({String? searchQuery, String? subjectId}) async {
    final queryParams = <String, String>{};
    if (subjectId != null && subjectId.isNotEmpty) {
      queryParams['subject_id'] = subjectId;
    }

    final response = await apiClient.get('/api/v1/notes', queryParams: queryParams);
    final list = response as List<dynamic>;
    var notes = list.map((json) => _noteFromJson(json as Map<String, dynamic>)).toList();

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      notes = notes.where((n) {
        return n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q) ||
            n.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    return notes;
  }

  @override
  Future<NoteModel?> getNoteById(String id) async {
    try {
      final response = await apiClient.get('/api/v1/notes/$id');
      return _noteFromJson(response as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<NoteModel> createNote({
    required String title,
    required String subjectId,
    required String subjectTitle,
    String content = '',
    List<String> tags = const [],
  }) async {
    final response = await apiClient.post(
      '/api/v1/notes',
      body: {
        'subject_id': subjectId,
        'title': title,
        'content': content,
        'tags': tags,
      },
    );
    final note = _noteFromJson(response as Map<String, dynamic>);
    return note.copyWith(subjectTitle: subjectTitle);
  }

  @override
  Future<NoteModel> updateNote(NoteModel note) async {
    final response = await apiClient.put(
      '/api/v1/notes/${note.id}',
      body: {
        'title': note.title,
        'content': note.content,
        'tags': note.tags,
        'subject_id': note.subjectId,
      },
    );
    final updated = _noteFromJson(response as Map<String, dynamic>);
    return updated.copyWith(subjectTitle: note.subjectTitle);
  }

  @override
  Future<void> deleteNote(String id) async {
    await apiClient.delete('/api/v1/notes/$id');
  }

  NoteModel _noteFromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as List<dynamic>? ?? [];
    final updatedAtStr = json['updated_at'] as String?;
    final updatedAt = updatedAtStr != null
        ? DateTime.tryParse(updatedAtStr)?.toLocal() ?? DateTime.now()
        : DateTime.now();

    return NoteModel(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      subjectTitle: json['subject_title'] as String? ?? 'Subject',
      title: json['title'] as String,
      content: json['content'] as String? ?? '',
      updatedAt: updatedAt,
      tags: rawTags.map((e) => e.toString()).toList(),
    );
  }
}
