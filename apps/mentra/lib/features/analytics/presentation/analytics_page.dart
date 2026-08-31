import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_page_header.dart';
import '../../../shared/widgets/mentra_section.dart';
import '../../../shared/widgets/mentra_stat_card.dart';
import '../data/mock_analytics.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MentraPageHeader(
          title: 'Analytics',
          subtitle: 'Your learning performance, telemetry insights, and focus history',
        ),

        // Key Stat Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            final cards = [
              const MentraStatCard(
                label: 'Focus Score',
                value: MockAnalyticsData.overallFocusScore,
                icon: Icons.auto_graph_rounded,
                iconColor: AppColors.success,
              ),
              const MentraStatCard(
                label: 'Study Time',
                value: MockAnalyticsData.totalStudyTime,
                icon: Icons.access_time_rounded,
              ),
              const MentraStatCard(
                label: 'Sessions',
                value: MockAnalyticsData.totalSessions,
                icon: Icons.calendar_today_outlined,
              ),
              const MentraStatCard(
                label: 'Distractions',
                value: MockAnalyticsData.totalDistractions,
                icon: Icons.notifications_off_outlined,
                iconColor: AppColors.warning,
              ),
            ];

            if (isNarrow) {
              return Column(
                children: cards
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: c,
                        ))
                    .toList(),
              );
            }

            return Row(
              children: cards
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

        const SizedBox(height: AppSpacing.xl),

        // Focus Trend Section
        MentraSection(
          title: 'Focus Trend',
          subtitle: 'Weekly average focus performance',
          child: MentraCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Weekly Attention Average',
                      style: AppTypography.titleSmall.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Target: 80%+',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: MockAnalyticsData.weeklyTrend.map((point) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${(point.score * 100).toInt()}%',
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 28,
                            height: 90 * point.score,
                            decoration: BoxDecoration(
                              color: point.score >= 0.85
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(alpha: 0.6),
                              borderRadius: AppRadius.borderSm,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            point.day,
                            style: AppTypography.labelSmall.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Study Consistency & Subject Breakdown
        MentraSection(
          title: 'Subject Distribution',
          subtitle: 'Hours spent per subject this week',
          child: MentraCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: MockAnalyticsData.subjectBreakdown.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.subject,
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${item.hours} hrs (${(item.percentage * 100).toInt()}%)',
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2C) : AppColors.lightBorder,
                          borderRadius: AppRadius.borderFull,
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: item.percentage,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: AppRadius.borderFull,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
