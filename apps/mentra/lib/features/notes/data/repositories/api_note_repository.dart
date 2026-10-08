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

      if (notes.isEmpty && fallbackRepository != null) {
        // If backend has no notes yet for this user, check local/fallback repository
        final fallbackList = await fallbackRepository!.getNotes(searchQuery: searchQuery, subjectId: subjectId);
        if (fallbackList.isNotEmpty) {
          // Sync fallback notes to backend in background
          for (final fn in fallbackList) {
            _syncToBackend(fn);
          }
          return fallbackList;
        }
      }

      // Keep fallback repository in sync with backend
      if (fallbackRepository != null && notes.isNotEmpty) {
        for (final n in notes) {
          try {
            await fallbackRepository!.updateNote(n);
          } catch (_) {}
        }
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        notes = notes.where((n) {
          return n.title.toLowerCase().contains(q) ||
              n.content.toLowerCase().contains(q) ||
              n.subjectTitle.toLowerCase().contains(q) ||
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

  void _syncToBackend(NoteModel note) async {
    try {
      await apiClient.post(
        '/api/v1/notes',
        body: {
          'subject_id': note.subjectId,
          'title': note.title,
          'content': note.content,
          'tags': note.tags,
        },
      );
    } catch (_) {}
  }

  @override
  Future<NoteModel?> getNoteById(String id) async {
    try {
      final response = await apiClient.get('/api/v1/notes/$id');
      final note = _noteFromJson(response as Map<String, dynamic>);
      if (fallbackRepository != null) {
        try {
          await fallbackRepository!.updateNote(note);
        } catch (_) {}
      }
      return note;
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
      final note = _noteFromJson(response as Map<String, dynamic>).copyWith(subjectTitle: subjectTitle);
      if (fallbackRepository != null) {
        try {
          await fallbackRepository!.updateNote(note);
        } catch (_) {}
      }
      return note;
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
    NoteModel? result;

    // 1. Try updating via PUT to backend
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
      result = updated.copyWith(subjectTitle: note.subjectTitle);
    } catch (putError) {
      // 2. If PUT fails (e.g. 404 because note had local/mock id), try POST to create/upsert it
      try {
        final response = await apiClient.post(
          '/api/v1/notes',
          body: {
            'subject_id': note.subjectId,
            'title': note.title,
            'content': note.content,
            'tags': note.tags,
          },
        );
        final created = _noteFromJson(response as Map<String, dynamic>);
        result = created.copyWith(subjectTitle: note.subjectTitle);
      } catch (_) {
        // Backend completely unreachable or errored
      }
    }

    // 3. Always ensure fallback repository (local storage) is updated
    if (fallbackRepository != null) {
      try {
        final fallbackUpdated = await fallbackRepository!.updateNote(result ?? note);
        result ??= fallbackUpdated;
      } catch (_) {
        try {
          final fallbackCreated = await fallbackRepository!.createNote(
            title: note.title,
            subjectId: note.subjectId,
            subjectTitle: note.subjectTitle,
            content: note.content,
            tags: note.tags,
          );
          result ??= fallbackCreated;
        } catch (_) {}
      }
    }

    if (result != null) {
      return result;
    }

    throw Exception('Failed to save note to server and local storage.');
  }

  @override
  Future<void> deleteNote(String id) async {
    try {
      await apiClient.delete('/api/v1/notes/$id');
    } catch (_) {}
    if (fallbackRepository != null) {
      try {
        await fallbackRepository!.deleteNote(id);
      } catch (_) {}
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
