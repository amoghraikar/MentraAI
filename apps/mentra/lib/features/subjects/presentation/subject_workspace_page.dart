import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_progress_bar.dart';
import '../../../shared/widgets/mentra_section.dart';
import '../../../shared/widgets/mentra_stat_card.dart';
import '../domain/models/subject_model.dart';
import '../domain/models/topic_model.dart';
import '../domain/repositories/subject_repository.dart';

class SubjectWorkspacePage extends StatefulWidget {
  const SubjectWorkspacePage({
    super.key,
    required this.subjectId,
    required this.subjectRepository,
    required this.onBack,
    required this.onOpenTopic,
    required this.onStartStudySession,
  });

  final String subjectId;
  final SubjectRepository subjectRepository;
  final VoidCallback onBack;
  final void Function(SubjectModel subject, TopicModel topic) onOpenTopic;
  final void Function(String subjectId, String? topicId) onStartStudySession;

  @override
  State<SubjectWorkspacePage> createState() => _SubjectWorkspacePageState();
}

class _SubjectWorkspacePageState extends State<SubjectWorkspacePage> {
  SubjectModel? _subject;
  bool _isLoading = true;
  int _selectedTab = 0;

  final List<String> _tabs = ['Overview', 'Topics', 'Notes', 'Sessions'];

  @override
  void initState() {
    super.initState();
    _loadSubject();
  }

  Future<void> _loadSubject() async {
    final sub = await widget.subjectRepository.getSubjectById(widget.subjectId);
    if (!mounted) return;
    setState(() {
      _subject = sub;
      _isLoading = false;
    });
  }

  void _showAddTopicDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
        title: const Text('Add New Topic'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Topic Title', style: AppTypography.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(hintText: 'e.g. Eigenvalues & Vector Spaces'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Description / Concepts', style: AppTypography.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: descController,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Brief summary of key learning objectives'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          MentraButton(
            label: 'Add Topic',
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
      await widget.subjectRepository.addTopic(
        subjectId: widget.subjectId,
        title: titleController.text.trim(),
        description: descController.text.trim().isNotEmpty
            ? descController.text.trim()
            : 'Conceptual study unit.',
      );
      _loadSubject();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_subject == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Subject not found', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.md),
            MentraButton(label: 'Back to Subjects', onPressed: widget.onBack),
          ],
        ),
      );
    }

    final sub = _subject!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Breadcrumb Navigation Bar
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: widget.onBack,
              tooltip: 'Back to Subjects',
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Subjects',
              style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
            Text(
              sub.title,
              style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // Workspace Header Banner Card
        MentraCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
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
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  MentraButton(
                    label: 'Start Study Session',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => widget.onStartStudySession(sub.id, null),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                sub.title,
                style: AppTypography.displayMedium.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                sub.description,
                style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: MentraProgressBar(
                      value: sub.overallProgress,
                      label: 'Subject Mastery',
                      valueLabel: '${(sub.overallProgress * 100).toInt()}%',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  Text(
                    '${sub.completedTopicsCount}/${sub.topics.length} Topics Completed',
                    style: AppTypography.labelSmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Navigation Tabs
        Row(
          children: List.generate(_tabs.length, (index) {
            final isSelected = _selectedTab == index;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                          : (isDark ? const Color(0xFF222222) : const Color(0xFFF2F2F0)),
                      borderRadius: AppRadius.borderSm,
                      border: Border.all(
                        color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _tabs[index],
                      style: AppTypography.labelMedium.copyWith(
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Tab Content
        _buildActiveTab(sub),
      ],
    );
  }

  Widget _buildActiveTab(SubjectModel sub) {
    switch (_selectedTab) {
      case 0:
        return _buildOverviewTab(sub);
      case 1:
        return _buildTopicsTab(sub);
      case 2:
        return _buildNotesTab(sub);
      case 3:
        return _buildSessionsTab(sub);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverviewTab(SubjectModel sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: MentraStatCard(
                title: 'Total Study Time',
                value: '${sub.totalHours} hrs',
                subtitle: 'Target: ${sub.targetHours} hrs',
                icon: Icons.timer_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MentraStatCard(
                title: 'Topics Count',
                value: '${sub.topics.length}',
                subtitle: '${sub.completedTopicsCount} mastered',
                icon: Icons.bookmark_border_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: MentraStatCard(
                title: 'Avg Focus Baseline',
                value: '86%',
                subtitle: 'High retention zone',
                icon: Icons.insights_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildTopicsTab(sub),
      ],
    );
  }

  Widget _buildTopicsTab(SubjectModel sub) {
    return MentraSection(
      title: 'Coursework Topics',
      subtitle: 'Structured units for targeted study and practice',
      action: MentraButton(
        label: 'New Topic',
        icon: Icons.add_rounded,
        variant: MentraButtonVariant.secondary,
        onPressed: _showAddTopicDialog,
      ),
      child: sub.topics.isEmpty
          ? const Center(child: Text('No topics added yet.'))
          : Column(
              children: sub.topics.map((topic) {
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    topic.title,
                                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    topic.description,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Row(
                              children: [
                                MentraButton(
                                  label: 'View Topic',
                                  variant: MentraButtonVariant.outline,
                                  onPressed: () => widget.onOpenTopic(sub, topic),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                MentraButton(
                                  label: 'Study',
                                  icon: Icons.play_arrow_rounded,
                                  variant: MentraButtonVariant.primary,
                                  onPressed: () => widget.onStartStudySession(sub.id, topic.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        MentraProgressBar(
                          value: topic.progress,
                          label: '${(topic.progress * 100).toInt()}% Complete',
                          valueLabel: '${topic.totalMinutes} min studied',
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildNotesTab(SubjectModel sub) {
    return MentraSection(
      title: 'Subject Notes',
      subtitle: 'All study notes related to ${sub.title}',
      child: MentraCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: sub.topics.map((t) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(t.title, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text(t.notesSnippet.isNotEmpty ? t.notesSnippet : 'Key notes for this unit.', maxLines: 1),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => widget.onOpenTopic(sub, t),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSessionsTab(SubjectModel sub) {
    return MentraSection(
      title: 'Recent Subject Sessions',
      subtitle: 'Historical focus telemetry for this coursework',
      child: MentraCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_outlined, color: AppColors.success),
              title: Text('Linear & Multiple Regression', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              subtitle: const Text('52 min • 88% Focus Score • 2 Distractions'),
              trailing: const MentraBadge(label: 'High Focus', variant: MentraBadgeVariant.success),
            ),
            Divider(color: Theme.of(context).dividerColor),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_outlined, color: AppColors.success),
              title: Text('Correlation & Covariance', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              subtitle: const Text('60 min • 91% Focus Score • 1 Distraction'),
              trailing: const MentraBadge(label: 'Peak Focus', variant: MentraBadgeVariant.success),
            ),
          ],
        ),
      ),
    );
  }
}
