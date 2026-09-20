import '../../../../core/network/api_client.dart';
import '../../domain/models/note_model.dart';
import '../../domain/repositories/note_repository.dart';

class ApiNoteRepository implements NoteRepository {
  ApiNoteRepository({
    required this.apiClient,
    this.fallbackRepository,
  });

  final ApiClient apiClient;
  final NoteRepository? fallbackRepository;

  @override
  Future<List<NoteModel>> getNotes({String? searchQuery, String? subjectId}) async {
    try {
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
    } catch (_) {
      if (fallbackRepository != null) {
        return fallbackRepository!.getNotes(searchQuery: searchQuery, subjectId: subjectId);
      }
      rethrow;
    }
  }

  @override
  Future<NoteModel?> getNoteById(String id) async {
    try {
      final response = await apiClient.get('/api/v1/notes/$id');
      return _noteFromJson(response as Map<String, dynamic>);
    } catch (_) {
      if (fallbackRepository != null) {
        return fallbackRepository!.getNoteById(id);
      }
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
    try {
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
    } catch (_) {
      if (fallbackRepository != null) {
        return fallbackRepository!.createNote(
          title: title,
          subjectId: subjectId,
          subjectTitle: subjectTitle,
          content: content,
          tags: tags,
        );
      }
      rethrow;
    }
  }

  @override
  Future<NoteModel> updateNote(NoteModel note) async {
    try {
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
    } catch (_) {
      if (fallbackRepository != null) {
        return fallbackRepository!.updateNote(note);
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    try {
      await apiClient.delete('/api/v1/notes/$id');
    } catch (_) {
      if (fallbackRepository != null) {
        await fallbackRepository!.deleteNote(id);
        return;
      }
      rethrow;
    }
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
