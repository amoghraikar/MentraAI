import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_page_header.dart';
import '../../../shared/widgets/mentra_progress_bar.dart';
import '../data/mock_subjects.dart';

class SubjectsPage extends StatelessWidget {
  const SubjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MentraPageHeader(
          title: 'Subjects',
          subtitle: 'Your study subjects and curriculum progress',
          action: MentraButton(
            label: 'New Subject',
            icon: Icons.add_rounded,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Subject creation will be available in future milestones.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),

        // List of Subjects
        ...MockSubjectsData.subjects.map((subject) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.base),
            child: MentraCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              onTap: () => _showSubjectDetail(context, subject),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject.title,
                              style: AppTypography.titleLarge.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              subject.description,
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF262626)
                              : const Color(0xFFF2F2F0),
                          borderRadius: AppRadius.borderSm,
                        ),
                        child: Text(
                          '${subject.totalHours} hrs • ${subject.totalSessions} sessions',
                          style: AppTypography.labelSmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Topic tags
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: subject.topics.map((topic) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: AppRadius.borderSm,
                        ),
                        child: Text(
                          topic,
                          style: AppTypography.labelSmall.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: AppSpacing.base),

                  // Progress Bar
                  MentraProgressBar(
                    percentage: subject.progress,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showSubjectDetail(BuildContext context, SubjectItem subject) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
          title: Text(subject.title, style: AppTypography.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject.description,
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Topics Covered:',
                style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xs),
              ...subject.topics.map((t) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 6),
                        const SizedBox(width: AppSpacing.sm),
                        Text(t, style: AppTypography.bodySmall),
                      ],
                    ),
                  )),
              const SizedBox(height: AppSpacing.md),
              MentraProgressBar(percentage: subject.progress),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
