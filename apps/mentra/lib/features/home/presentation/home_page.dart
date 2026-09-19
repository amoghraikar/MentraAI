import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
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
        Builder(
          builder: (context) {
            final totalMins = _stats['totalMinutes'] as int? ?? 0;
            final hours = totalMins ~/ 60;
            final mins = totalMins % 60;
            final formattedStudyTime = totalMins > 0 ? '${hours}h ${mins}m' : '0m';

            final avgFocus = _stats['averageFocusScore'] as int? ?? 0;
            final formattedFocus = avgFocus > 0 ? '$avgFocus%' : '0%';

            final sessionCount = _stats['completedSessionsCount'] as int? ?? 0;

            return MentraSection(
              title: "Today's Progress",
              subtitle: 'Daily learning time, average focus score, and active sessions',
              child: Row(
                children: [
                  Expanded(
                    child: MentraStatCard(
                      title: 'Study Time',
                      value: formattedStudyTime,
                      subtitle: totalMins > 0 ? 'Total logged focus time' : 'No study time logged yet',
                      icon: Icons.timer_outlined,
                      trendLabel: totalMins > 0 ? 'Active' : 'Start Session',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MentraStatCard(
                      title: 'Focus Score',
                      value: formattedFocus,
                      subtitle: avgFocus > 0 ? 'Attention baseline' : 'Calculated during sessions',
                      icon: Icons.insights_outlined,
                      trendLabel: avgFocus >= 80 ? 'High' : (avgFocus > 0 ? 'Moderate' : 'No Data'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MentraStatCard(
                      title: 'Sessions',
                      value: '$sessionCount',
                      subtitle: 'Completed study blocks',
                      icon: Icons.check_circle_outline_rounded,
                      trendLabel: sessionCount > 0 ? 'Logged' : 'Ready',
                    ),
                  ),
                ],
              ),
            );
          },
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
                          Text(
                            _recentSessions.isEmpty ? 'Cognitive Baseline' : 'Focus Endurance',
                            style: AppTypography.labelMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _recentSessions.isEmpty
                            ? 'No study sessions recorded yet. Complete your first study block with on-device focus tracking to establish your real attention baseline.'
                            : 'Your average attention score across ${_recentSessions.length} logged session(s) is ${_stats['averageFocusScore'] ?? 0}%. Continue pacing 45-minute blocks for maximum retention.',
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
