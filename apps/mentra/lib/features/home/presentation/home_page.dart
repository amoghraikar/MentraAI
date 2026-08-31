import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_progress_bar.dart';
import '../../../shared/widgets/mentra_section.dart';
import '../../../shared/widgets/mentra_stat_card.dart';
import '../data/mock_home_data.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Hero Greeting & Quick Action
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MockHomeData.greeting,
                  style: AppTypography.displayMedium.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  MockHomeData.focusPrompt,
                  style: AppTypography.bodyLarge.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            MentraButton(
              label: 'Start Study Session',
              icon: Icons.play_arrow_rounded,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Study Session workflow will be available in future milestones.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        Divider(color: theme.dividerColor, height: 1),
        const SizedBox(height: AppSpacing.xl),

        // Today's Progress Section
        MentraSection(
          title: "Today's Progress",
          subtitle: "Summary of your study telemetry today",
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              final statCards = [
                const MentraStatCard(
                  label: 'Study Time',
                  value: MockHomeData.todayStudyTime,
                  icon: Icons.timer_outlined,
                ),
                const MentraStatCard(
                  label: 'Focus Score',
                  value: MockHomeData.todayFocusScore,
                  icon: Icons.auto_graph_rounded,
                  iconColor: AppColors.success,
                ),
                const MentraStatCard(
                  label: 'Sessions',
                  value: MockHomeData.todaySessionsCount,
                  icon: Icons.donut_large_rounded,
                ),
              ];

              if (isNarrow) {
                return Column(
                  children: statCards
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: c,
                          ))
                      .toList(),
                );
              }

              return Row(
                children: statCards
                    .map((card) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                            child: card,
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ),

        // Continue Studying Section
        MentraSection(
          title: 'Continue Studying',
          subtitle: 'Pick up where you left off',
          child: MentraCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0EE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.school_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        MockHomeData.continueSubject.subject,
                        style: AppTypography.titleSmall.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        MockHomeData.continueSubject.topic,
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      MentraProgressBar(
                        percentage: MockHomeData.continueSubject.progress,
                        height: 4,
                        showLabel: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                MentraButton(
                  label: 'Continue',
                  variant: MentraButtonVariant.secondary,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),

        // Recent Sessions Section
        MentraSection(
          title: 'Recent Sessions',
          subtitle: 'Your recent study activity',
          child: Column(
            children: MockHomeData.recentSessions.map((session) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: MentraCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          session.subject,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        session.duration,
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          session.focusScore,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Mentra Insight Highlight
        MentraSection(
          title: 'Mentra Insight',
          child: MentraCard(
            backgroundColor: isDark
                ? const Color(0xFF1E2638)
                : const Color(0xFFF1F5F9),
            borderColor: isDark
                ? const Color(0xFF2E3D5B)
                : const Color(0xFFCBD5E1),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.base),
                Expanded(
                  child: Text(
                    MockHomeData.dailyInsight,
                    style: AppTypography.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
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
