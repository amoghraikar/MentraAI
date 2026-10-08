import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/dialogs/mentra_dialogs.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../domain/models/note_model.dart';
import '../domain/repositories/note_repository.dart';

class NoteEditorView extends StatefulWidget {
  const NoteEditorView({
    super.key,
    required this.note,
    required this.noteRepository,
    required this.onBack,
    this.onNoteUpdated,
  });

  final NoteModel note;
  final NoteRepository noteRepository;
  final VoidCallback onBack;
  final ValueChanged<NoteModel>? onNoteUpdated;

  @override
  State<NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends State<NoteEditorView> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _isSaving = false;
  late NoteModel _currentNote;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _titleController = TextEditingController(text: _currentNote.title);
    _contentController = TextEditingController(text: _currentNote.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'Untitled Note';
    final updated = _currentNote.copyWith(
      title: title,
      content: _contentController.text,
      updatedAt: DateTime.now(),
    );
    try {
      final saved = await widget.noteRepository.updateNote(updated);
      if (!mounted) return;
      setState(() {
        _currentNote = saved;
        _isSaving = false;
      });
      widget.onNoteUpdated?.call(saved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Note saved successfully.'),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Failed to save note: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final shouldDelete = await MentraConfirmDialog.show(
      context: context,
      title: 'Delete Note?',
      message: 'Are you sure you want to delete this study note? This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (shouldDelete) {
      await widget.noteRepository.deleteNote(_currentNote.id);
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final wordCount = _contentController.text.trim().isEmpty
        ? 0
        : _contentController.text.trim().split(RegExp(r'\s+')).length;
    final charCount = _contentController.text.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Toolbar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  onPressed: widget.onBack,
                  tooltip: 'Back to Notes',
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Notes',
                  style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.chevron_right_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _currentNote.subjectTitle,
                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '$wordCount words • $charCount chars',
                  style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.md),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                  tooltip: 'Delete Note',
                  onPressed: _delete,
                ),
                const SizedBox(width: AppSpacing.xs),
                MentraButton(
                  label: 'Save Note',
                  icon: Icons.save_outlined,
                  isLoading: _isSaving,
                  onPressed: _save,
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // Document Editor Container
        MentraCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tags Bar
              Row(
                children: [
                  MentraBadge(
                    label: _currentNote.subjectTitle,
                    variant: MentraBadgeVariant.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ..._currentNote.tags.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: MentraBadge(label: t, variant: MentraBadgeVariant.neutral),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Editable Title
              TextField(
                controller: _titleController,
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                  letterSpacing: -0.4,
                ),
                decoration: InputDecoration(
                  hintText: 'Note Title...',
                  hintStyle: AppTypography.headlineSmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                    fontSize: 24,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),

              const SizedBox(height: AppSpacing.sm),
              Divider(color: theme.dividerColor, height: 1),
              const SizedBox(height: AppSpacing.md),

              // Editable Multi-line Content
              TextField(
                controller: _contentController,
                minLines: 12,
                maxLines: null,
                style: AppTypography.bodyMedium.copyWith(
                  height: 1.6,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Start writing your study notes or paste lecture summaries...',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
