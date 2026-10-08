import 'package:flutter/material.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_empty_state.dart';
import '../../../shared/widgets/mentra_page_header.dart';
import '../../subjects/domain/models/subject_model.dart';
import '../../subjects/domain/repositories/subject_repository.dart';
import '../domain/models/note_model.dart';
import '../domain/repositories/note_repository.dart';
import 'note_editor_view.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({
    super.key,
    required this.noteRepository,
    this.subjectRepository,
  });

  final NoteRepository noteRepository;
  final SubjectRepository? subjectRepository;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<NoteModel> _notes = [];
  List<SubjectModel> _availableSubjects = [];
  bool _isLoading = true;
  String _searchQuery = '';
  NoteModel? _selectedNoteForEditing;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    if (widget.subjectRepository != null) {
      try {
        final subs = await widget.subjectRepository!.getSubjects();
        if (mounted && subs.isNotEmpty) {
          setState(() {
            _availableSubjects = subs;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadNotes() async {
    try {
      final list = await widget.noteRepository.getNotes(searchQuery: _searchQuery);
      if (!mounted) return;
      setState(() {
        _notes = list;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notes = [];
        _isLoading = false;
      });
    }
  }

  void _showNewNoteDialog() async {
    final titleController = TextEditingController();
    final options = _availableSubjects.isNotEmpty
        ? _availableSubjects.map((s) => s.title).toList()
        : ['Data Analytics', 'Software Engineering', 'Web Programming'];

    String subject = options.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
        title: const Text('Create New Study Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Note Title', style: AppTypography.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(hintText: 'e.g. Statistical Inference & Z-Scores'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Subject Tag', style: AppTypography.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<String>(
              initialValue: subject,
              items: options
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => subject = v ?? subject,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          MentraButton(
            label: 'Create Note',
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              }
            },
          ),
        ],
      ),
    );

    if (result == true && titleController.text.trim().isNotEmpty) {
      String subjectId = 'sub_gen';
      final matchingSub = _availableSubjects.cast<SubjectModel?>().firstWhere(
        (s) => s?.title.toLowerCase() == subject.toLowerCase(),
        orElse: () => null,
      );
      if (matchingSub != null) {
        subjectId = matchingSub.id;
      } else {
        if (subject == 'Data Analytics') {
          subjectId = 'sub_1';
        } else if (subject == 'Software Engineering') {
          subjectId = 'sub_2';
        } else if (subject == 'Web Programming') {
          subjectId = 'sub_3';
        }
      }

      try {
        final newNote = await widget.noteRepository.createNote(
          title: titleController.text.trim(),
          subjectId: subjectId,
          subjectTitle: subject,
          content: '# ${titleController.text.trim()}\n\nStart typing notes here...',
          tags: [subject.split(' ').first, 'Notes'],
        );
        await _loadNotes();
        if (mounted) {
          setState(() => _selectedNoteForEditing = newNote);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create note: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedNoteForEditing != null) {
      return NoteEditorView(
        note: _selectedNoteForEditing!,
        noteRepository: widget.noteRepository,
        onNoteUpdated: (updated) {
          setState(() {
            _selectedNoteForEditing = updated;
            final idx = _notes.indexWhere((n) => n.id == updated.id);
            if (idx != -1) {
              _notes[idx] = updated;
            } else {
              _notes.insert(0, updated);
            }
          });
        },
        onBack: () {
          setState(() => _selectedNoteForEditing = null);
          _loadNotes();
        },
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MentraPageHeader(
          title: 'Notes',
          subtitle: 'Capture lecture notes, formulas, and structured summaries',
          action: MentraButton(
            label: 'New Note',
            icon: Icons.add_rounded,
            onPressed: _showNewNoteDialog,
          ),
        ),

        // Search & Filter Bar
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) {
                  _searchQuery = v;
                  _loadNotes();
                },
                decoration: InputDecoration(
                  hintText: 'Search notes by title, topic, or content...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.borderSm,
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.borderSm,
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // Notes List / Grid
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_notes.isEmpty)
          MentraEmptyState(
            icon: Icons.description_outlined,
            title: _searchQuery.isNotEmpty ? 'No matching notes found' : 'No notes created yet',
            description: _searchQuery.isNotEmpty
                ? 'Try searching for different keywords or subject tags'
                : 'Create your first study note to capture formulas, key concepts, and takeaways.',
            actionLabel: 'Create First Note',
            onAction: _showNewNoteDialog,
          )
        else
          Column(
            children: _notes.map((note) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: MentraCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              MentraBadge(
                                label: note.subjectTitle,
                                variant: MentraBadgeVariant.primary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              ...note.tags.map(
                                (t) => Padding(
                                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                                  child: MentraBadge(label: t, variant: MentraBadgeVariant.neutral),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${note.wordCount} words',
                            style: AppTypography.labelSmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        note.title,
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        note.content.replaceAll(RegExp(r'[#*`\n]'), ' ').trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Updated ${_formatDate(note.updatedAt)}',
                            style: AppTypography.labelSmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          MentraButton(
                            label: 'Open Note',
                            variant: MentraButtonVariant.outline,
                            onPressed: () => setState(() => _selectedNoteForEditing = note),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  String _formatDate(DateTime dt) => Formatters.formatRelativeTime(dt);
}
