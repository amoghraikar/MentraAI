import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_empty_state.dart';
import '../../../shared/widgets/mentra_page_header.dart';
import '../../../shared/widgets/mentra_progress_bar.dart';
import '../../../shared/widgets/mentra_section.dart';
import '../../../shared/widgets/mentra_stat_card.dart';
import '../domain/models/analytics_data.dart';
import '../domain/repositories/analytics_repository.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({
    super.key,
    required this.analyticsRepository,
  });

  final AnalyticsRepository analyticsRepository;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  AnalyticsOverviewModel? _data;
  AnalyticsTimeRange _selectedRange = AnalyticsTimeRange.sevenDays;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.analyticsRepository.getAnalyticsSummary(
        timeRange: _selectedRange,
      );
      if (!mounted) return;
      setState(() {
        _data = res;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onRangeChanged(AnalyticsTimeRange range) {
    if (_selectedRange == range) return;
    setState(() => _selectedRange = range);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading && _data == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final data = _data;
    final hasData = data != null && data.hasData;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: MentraPageHeader(
                  title: 'Analytics',
                  subtitle: 'Study behavior, attention telemetry, subject allocation, and verified insights',
                ),
              ),
              // Time-Range Switcher
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: AnalyticsTimeRange.values.map((range) {
                    final isSelected = _selectedRange == range;
                    return GestureDetector(
                      onTap: () => _onRangeChanged(range),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          range.label,
                          style: AppTypography.labelSmall.copyWith(
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          if (!hasData && !_isLoading) ...[
            const SizedBox(height: AppSpacing.xl),
            MentraCard(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: MentraEmptyState(
                icon: Icons.insights_outlined,
                title: 'No study data for ${_selectedRange.label}',
                subtitle: 'Complete a study session to generate focus telemetry, distraction breakdowns, and AI intelligence insights.',
              ),
            ),
          ] else if (data != null) ...[
            // Key Performance Indicators Row
            Row(
              children: [
                Expanded(
                  child: MentraStatCard(
                    title: 'Total Study Time',
                    value: data.totalStudyTimeFormatted,
                    subtitle: 'Range: ${_selectedRange.label}',
                    icon: Icons.timer_outlined,
                    trendLabel: '${data.totalStudyMinutes} mins total',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MentraStatCard(
                    title: 'Sessions Completed',
                    value: '${data.completedSessionsCount}',
                    subtitle: 'Avg ${data.averageSessionDurationMinutes}m / session',
                    icon: Icons.check_circle_outline_rounded,
                    trendLabel: '${data.totalSessionsCount} total',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MentraStatCard(
                    title: 'Average Focus',
                    value: '${data.averageFocusScore}%',
                    subtitle: 'Attention Baseline',
                    icon: Icons.insights_outlined,
                    trendLabel: data.averageFocusScore >= 80 ? 'Optimal' : 'Needs Focus',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MentraStatCard(
                    title: 'Consistency Score',
                    value: '${data.streakSummary.currentStreakDays} Days',
                    subtitle: 'Best: ${data.streakSummary.longestStreakDays} days',
                    icon: Icons.local_fire_department_rounded,
                    trendLabel: '${data.streakSummary.activeDaysPercent}% active',
                  ),
                ),
              ],
            ),

            // AI Study Intelligence Insight Card
            if (data.aiInsight != null) ...[
              const SizedBox(height: AppSpacing.lg),
              MentraCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'AI Coach Intelligence',
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              MentraBadge(
                                label: data.aiInsight!.type,
                                variant: MentraBadgeVariant.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            data.aiInsight!.insight,
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (data.aiInsight!.suggestedAction != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 14,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Suggestion: ${data.aiInsight!.suggestedAction!}',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            // Focus Trend Bar Chart
            MentraSection(
              title: 'Daily Focus & Attention Trend',
              subtitle: 'Daily focus score and minutes studied over the period',
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
                            const Icon(Icons.show_chart_rounded, size: 18, color: AppColors.accent),
                            const SizedBox(width: AppSpacing.xs),
                            Text('Daily Attention Percentage', style: AppTypography.labelMedium),
                          ],
                        ),
                        const MentraBadge(label: 'Target: ≥80%', variant: MentraBadgeVariant.success),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (data.dailyTrends.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Center(child: Text('No daily timeline data available.')),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: data.dailyTrends.map((trend) {
                            final barHeight = ((trend.focusScore.clamp(0, 100)) * 1.3).toDouble();
                            final isTarget = trend.focusScore >= 80;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    trend.studyMinutes > 0 ? '${trend.focusScore}%' : '-',
                                    style: AppTypography.labelSmall.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isTarget && trend.studyMinutes > 0
                                          ? AppColors.success
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Container(
                                    width: 28,
                                    height: barHeight < 6 ? 6 : barHeight,
                                    decoration: BoxDecoration(
                                      color: trend.studyMinutes == 0
                                          ? theme.colorScheme.surfaceContainerHigh
                                          : (isTarget
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.primary.withValues(alpha: 0.45)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    trend.dayLabel,
                                    style: AppTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${trend.studyMinutes}m',
                                    style: AppTypography.labelSmall.copyWith(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Distraction Breakdown Section
            MentraSection(
              title: 'Distraction Telemetry Breakdown',
              subtitle: 'Classification of interruptions detected by computer vision during study blocks',
              child: Row(
                children: data.distractionBreakdown.map((category) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: MentraCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    category.category,
                                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                MentraBadge(
                                  label: '${category.percentage}%',
                                  variant: category.percentage > 30
                                      ? MentraBadgeVariant.danger
                                      : MentraBadgeVariant.neutral,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              '${category.count} events detected',
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              category.trendLabel,
                              style: AppTypography.labelSmall.copyWith(
                                color: category.trendLabel.contains('-')
                                    ? AppColors.success
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Subject Distribution & Goals Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject Allocation
                Expanded(
                  flex: 3,
                  child: MentraSection(
                    title: 'Subject Study Allocation',
                    subtitle: 'Time distribution across active learning subjects',
                    child: MentraCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: data.subjectDistribution.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.lg),
                                child: Text('No subject study distribution data.'),
                              ),
                            )
                          : Column(
                              children: data.subjectDistribution.map((sub) {
                                Color parsedColor;
                                try {
                                  final hex = sub.colorHex.replaceFirst('#', '');
                                  parsedColor = Color(int.parse('0xFF$hex'));
                                } catch (_) {
                                  parsedColor = theme.colorScheme.primary;
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: parsedColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: AppSpacing.xs),
                                                Expanded(
                                                  child: Text(
                                                    sub.title,
                                                    style: AppTypography.bodySmall.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          Text(
                                            '${sub.formattedTime} (${sub.percentage}%)',
                                            style: AppTypography.labelSmall.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      MentraProgressBar(
                                        percentage: sub.percentage / 100.0,
                                        color: parsedColor,
                                        showLabel: false,
                                        height: 6,
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Goal Summary
                Expanded(
                  flex: 2,
                  child: MentraSection(
                    title: 'Goal Milestones',
                    subtitle: 'Academic targets progress',
                    child: MentraCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Overall Completion',
                                style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                              ),
                              MentraBadge(
                                label: '${data.goalsSummary.completionRatePercent}%',
                                variant: data.goalsSummary.completionRatePercent >= 70
                                    ? MentraBadgeVariant.success
                                    : MentraBadgeVariant.neutral,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          MentraProgressBar(
                            percentage: data.goalsSummary.completionRatePercent / 100.0,
                            color: AppColors.success,
                            showLabel: false,
                            height: 8,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Completed', style: AppTypography.labelSmall, overflow: TextOverflow.ellipsis),
                                    Text(
                                      '${data.goalsSummary.completedGoals}',
                                      style: AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Active', style: AppTypography.labelSmall, overflow: TextOverflow.ellipsis),
                                    Text(
                                      '${data.goalsSummary.activeGoals}',
                                      style: AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total', style: AppTypography.labelSmall, overflow: TextOverflow.ellipsis),
                                    Text(
                                      '${data.goalsSummary.totalGoals}',
                                      style: AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
