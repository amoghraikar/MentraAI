import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_progress_bar.dart';
import '../../../shared/widgets/mentra_section.dart';
import '../../../shared/widgets/mentra_stat_card.dart';
import '../../study_session/domain/models/study_session_record.dart';
import '../../study_session/domain/repositories/session_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.sessionRepository,
    required this.onStartStudySession,
    required this.onOpenSubject,
  });

  final SessionRepository sessionRepository;
  final VoidCallback onStartStudySession;
  final void Function(String subjectId) onOpenSubject;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<StudySessionRecord> _recentSessions = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final sessions = await widget.sessionRepository.getRecentSessions(limit: 4);
    final stats = await widget.sessionRepository.getSessionStatistics();
    if (!mounted) return;
    setState(() {
      _recentSessions = sessions;
      _stats = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Header & Main CTA
        MentraCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Good morning',
                        style: AppTypography.displayMedium.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const MentraBadge(label: 'Workspace Active', variant: MentraBadgeVariant.success),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Ready to focus on your coursework today?',
                    style: AppTypography.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              MentraButton(
                label: 'Start Study Session',
                icon: Icons.play_arrow_rounded,
                onPressed: widget.onStartStudySession,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Today's Overview Metrics
        MentraSection(
          title: "Today's Progress",
          subtitle: 'Daily learning time, average focus score, and active sessions',
          child: Row(
            children: [
              Expanded(
                child: MentraStatCard(
                  title: 'Study Time',
                  value: _stats['totalStudyHours'] ?? '2h 15m',
                  subtitle: '+45m vs yesterday',
                  icon: Icons.timer_outlined,
                  trendLabel: 'On Track',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MentraStatCard(
                  title: 'Focus Score',
                  value: _stats['averageFocus'] ?? '84%',
                  subtitle: 'High attention baseline',
                  icon: Icons.insights_outlined,
                  trendLabel: 'High',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MentraStatCard(
                  title: 'Sessions',
                  value: '${_stats['totalSessions'] ?? 3}',
                  subtitle: 'Completed study blocks',
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Continue Studying Card
        MentraSection(
          title: 'Continue Studying',
          subtitle: 'Pick up right where you left off',
          child: MentraCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const MentraBadge(label: 'DATA ANALYTICS', variant: MentraBadgeVariant.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Unit II', style: AppTypography.labelSmall),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Correlation & Multiple Regression',
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Ordinary Least Squares (OLS) residual diagnostics and ANOVA F-tests',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const MentraProgressBar(
                        value: 0.78,
                        label: 'Topic Progress',
                        valueLabel: '78%',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                MentraButton(
                  label: 'Continue',
                  icon: Icons.play_arrow_rounded,
                  onPressed: widget.onStartStudySession,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Recent Sessions & AI Insight Grid
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recent Sessions List
            Expanded(
              flex: 3,
              child: MentraSection(
                title: 'Recent Sessions',
                subtitle: 'Completed study blocks & attention records',
                child: MentraCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _recentSessions.isEmpty
                      ? const Text('No study sessions completed yet.')
                      : Column(
                          children: _recentSessions.map((session) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.timer_outlined, size: 18, color: AppColors.success),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                session.topicTitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                              ),
                                              Text(
                                                '${session.subjectTitle} • ${session.durationMinutes} min',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.bodySmall.copyWith(
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  MentraBadge(
                                    label: '${session.focusScore}% Focus',
                                    variant: session.focusScore >= 85
                                        ? MentraBadgeVariant.success
                                        : MentraBadgeVariant.neutral,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            // Mentra Insight
            Expanded(
              flex: 2,
              child: MentraSection(
                title: 'Mentra Insight',
                subtitle: 'Behavioral pattern recognition',
                child: MentraCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.psychology_outlined, color: AppColors.accent, size: 20),
                          const SizedBox(width: AppSpacing.xs),
                          Text('Peak Attention Window', style: AppTypography.labelMedium),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Your focus is usually strongest during the first 45 minutes of studying. Taking a 10-minute break after this window prevents the 35% cognitive drop observed in longer sessions.',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
