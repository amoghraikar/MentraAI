import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_page_header.dart';
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
  AnalyticsSummaryModel? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final res = await widget.analyticsRepository.getAnalyticsSummary();
    if (!mounted) return;
    setState(() {
      _data = res;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading || _data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _data!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MentraPageHeader(
          title: 'Analytics',
          subtitle: 'Comprehensive study behavior, attention metrics, and distraction telemetry',
        ),

        // Key Performance Indicators Row
        Row(
          children: [
            Expanded(
              child: MentraStatCard(
                title: 'Total Study Time',
                value: data.totalStudyTimeFormatted,
                subtitle: 'Past 7 days',
                icon: Icons.timer_outlined,
                trendLabel: '+2h 15m',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MentraStatCard(
                title: 'Sessions Completed',
                value: '${data.totalSessionsCount}',
                subtitle: '100% On-Device',
                icon: Icons.check_circle_outline_rounded,
                trendLabel: 'Optimal',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MentraStatCard(
                title: 'Average Focus',
                value: '${data.averageFocusScore}%',
                subtitle: 'Attention Baseline',
                icon: Icons.insights_outlined,
                trendLabel: '+4%',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MentraStatCard(
                title: 'Consistency Score',
                value: '${data.consistencyScore}%',
                subtitle: '5-day active streak',
                icon: Icons.auto_graph_rounded,
                trendLabel: 'Strong',
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // Focus Trend Bar Chart
        MentraSection(
          title: 'Daily Focus & Attention Trend',
          subtitle: 'Session focus score and minutes studied by day',
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
                    const MentraBadge(label: 'Target: >80%', variant: MentraBadgeVariant.success),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                // Custom Interactive Bars
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: data.weeklyTrends.map((trend) {
                    final height = (trend.focusScore * 1.5).toDouble();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${trend.focusScore}%',
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: trend.focusScore >= 80
                                ? AppColors.success
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Container(
                          width: 32,
                          height: height,
                          decoration: BoxDecoration(
                            color: trend.focusScore >= 80
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary.withValues(alpha: 0.4),
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
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Distraction Breakdown Section
        MentraSection(
          title: 'Distraction Telemetry Breakdown',
          subtitle: 'Classification of interruptions detected during study blocks',
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
                                category.name,
                                style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
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
      ],
    );
  }
}
