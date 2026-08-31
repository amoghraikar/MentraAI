import 'package:flutter/material.dart';
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

class TopicViewPage extends StatefulWidget {
  const TopicViewPage({
    super.key,
    required this.subject,
    required this.topic,
    required this.onBack,
    required this.onStartStudySession,
  });

  final SubjectModel subject;
  final TopicModel topic;
  final VoidCallback onBack;
  final void Function(String subjectId, String topicId) onStartStudySession;

  @override
  State<TopicViewPage> createState() => _TopicViewPageState();
}

class _TopicViewPageState extends State<TopicViewPage> {
  late List<bool> _checkedConcepts;

  @override
  void initState() {
    super.initState();
    _checkedConcepts = List.generate(
      widget.topic.keyConcepts.length,
      (index) => index < 2, // First 2 checked by default
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = widget.subject;
    final topic = widget.topic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb Navigation Bar
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: widget.onBack,
              tooltip: 'Back to ${sub.title}',
            ),
            const SizedBox(width: AppSpacing.xs),
            GestureDetector(
              onTap: widget.onBack,
              child: Text(
                sub.title,
                style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
            Text(
              topic.title,
              style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // Topic Main Header Card
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
                      Text(
                        sub.title.toUpperCase(),
                        style: AppTypography.labelSmall.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const MentraBadge(label: 'TOPIC VIEW', variant: MentraBadgeVariant.neutral),
                    ],
                  ),
                  MentraButton(
                    label: 'Start Session',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => widget.onStartStudySession(sub.id, topic.id),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                topic.title,
                style: AppTypography.displayMedium.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                topic.description,
                style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              MentraProgressBar(
                value: topic.progress,
                label: 'Topic Progress',
                valueLabel: '${(topic.progress * 100).toInt()}% Mastery',
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // 3 Key Stats
        Row(
          children: [
            Expanded(
              child: MentraStatCard(
                title: 'Time Invested',
                value: '${topic.totalMinutes} min',
                subtitle: 'Across 4 sessions',
                icon: Icons.timer_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MentraStatCard(
                title: 'Key Concepts',
                value: '${_checkedConcepts.where((c) => c).length}/${topic.keyConcepts.length}',
                subtitle: 'Checklist completed',
                icon: Icons.checklist_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: MentraStatCard(
                title: 'Focus Index',
                value: '88%',
                subtitle: 'High retention',
                icon: Icons.insights_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // Key Concepts Checklist
        MentraSection(
          title: 'Key Concepts & Checkpoints',
          subtitle: 'Verify conceptual mastery before examination',
          child: MentraCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: List.generate(topic.keyConcepts.length, (index) {
                final concept = topic.keyConcepts[index];
                final isChecked = _checkedConcepts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isChecked,
                        onChanged: (v) => setState(() => _checkedConcepts[index] = v ?? false),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          concept,
                          style: AppTypography.bodyMedium.copyWith(
                            decoration: isChecked ? TextDecoration.lineThrough : null,
                            color: isChecked
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Study Notes Snippet
        MentraSection(
          title: 'Study Notes & Formulas',
          subtitle: 'Quick reference from your study notebook',
          child: MentraCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.notesSnippet.isNotEmpty
                      ? topic.notesSnippet
                      : 'Capture structured notes during study sessions to review here.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
