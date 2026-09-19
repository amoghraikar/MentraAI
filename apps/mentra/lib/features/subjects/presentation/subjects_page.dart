import 'package:flutter/material.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/dialogs/mentra_dialogs.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_empty_state.dart';
import '../../../shared/widgets/mentra_page_header.dart';
import '../../../shared/widgets/mentra_progress_bar.dart';
import '../domain/models/subject_model.dart';
import '../domain/repositories/subject_repository.dart';

class SubjectsPage extends StatefulWidget {
  const SubjectsPage({
    super.key,
    required this.subjectRepository,
    required this.onSelectSubject,
    required this.onStartStudySession,
  });

  final SubjectRepository subjectRepository;
  final void Function(SubjectModel subject) onSelectSubject;
  final void Function(String subjectId) onStartStudySession;

  @override
  State<SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<SubjectsPage> {
  List<SubjectModel> _subjects = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final list = await widget.subjectRepository.getSubjects();
      if (!mounted) return;
      setState(() {
        _subjects = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showNewSubjectDialog() async {
    final titleCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedColor = '#3B82F6';

    final colors = ['#3B82F6', '#10B981', '#8B5CF6', '#F59E0B', '#EC4899'];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
          title: const Text('Add New Subject'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subject Title', style: AppTypography.labelSmall),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(hintText: 'e.g. Artificial Intelligence'),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Course Code', style: AppTypography.labelSmall),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(hintText: 'e.g. CS-501'),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Description', style: AppTypography.labelSmall),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(hintText: 'Brief coursework focus'),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Accent Color', style: AppTypography.labelSmall),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: colors.map((c) {
                  final isSel = selectedColor == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                          shape: BoxShape.circle,
                          border: isSel
                              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2)
                              : null,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            MentraButton(
              label: 'Create Subject',
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty) {
                  Navigator.of(ctx).pop(true);
                }
              },
            ),
          ],
        ),
      ),
    );

    if (result == true && titleCtrl.text.trim().isNotEmpty) {
      try {
        await widget.subjectRepository.createSubject(
          title: titleCtrl.text.trim(),
          code: codeCtrl.text.trim().isNotEmpty ? codeCtrl.text.trim().toUpperCase() : 'GEN-100',
          description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : 'Active coursework unit.',
          colorHex: selectedColor,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Subject "${titleCtrl.text.trim()}" created successfully!'),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not create subject: $e'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
      _loadSubjects();
    }
  }

  void _deleteSubject(SubjectModel sub) async {
    final confirmed = await MentraConfirmDialog.show(
      context: context,
      title: 'Delete "${sub.title}"?',
      message: 'This will remove the subject workspace, topics, and associated local telemetry.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed) {
      await widget.subjectRepository.deleteSubject(sub.id);
      _loadSubjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = _subjects.where((s) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.title.toLowerCase().contains(q) ||
          s.code.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MentraPageHeader(
          title: 'Subjects',
          subtitle: 'Your structured learning workspaces, topics, and coursework progression',
          action: MentraButton(
            label: 'New Subject',
            icon: Icons.add_rounded,
            onPressed: _showNewSubjectDialog,
          ),
        ),

        // Search Bar
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search subjects by title or code...',
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

        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (filtered.isEmpty)
          MentraEmptyState(
            icon: Icons.folder_outlined,
            title: _searchQuery.isNotEmpty ? 'No matching subjects found' : 'No subjects yet',
            subtitle: _searchQuery.isNotEmpty
                ? 'Try a different search keyword'
                : 'Create your first subject to organize topics, notes, and study sessions.',
            actionLabel: 'Add First Subject',
            onAction: _showNewSubjectDialog,
          )
        else
          Column(
            children: filtered.map((sub) {
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
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Color(int.parse(sub.colorHex.replaceFirst('#', '0xFF'))),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                sub.code,
                                style: AppTypography.labelSmall.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              MentraBadge(
                                label: '${sub.topics.length} topics',
                                variant: MentraBadgeVariant.neutral,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                tooltip: 'Delete Subject',
                                onPressed: () => _deleteSubject(sub),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              MentraButton(
                                label: 'Open Workspace',
                                variant: MentraButtonVariant.secondary,
                                onPressed: () => widget.onSelectSubject(sub),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              MentraButton(
                                label: 'Study',
                                icon: Icons.play_arrow_rounded,
                                variant: MentraButtonVariant.primary,
                                onPressed: () => widget.onStartStudySession(sub.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        sub.title,
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        sub.description,
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      MentraProgressBar(
                        value: sub.overallProgress,
                        label: '${(sub.overallProgress * 100).toInt()}% Complete',
                        valueLabel: '${sub.totalHours} hrs studied',
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
}
