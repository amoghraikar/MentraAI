import 'package:flutter/material.dart';
import '../../../core/routing/app_route.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_section.dart';
import '../../../shared/widgets/mentra_stat_card.dart';
import '../../auth/presentation/auth_controller.dart';
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
    try {
      final sessions = await widget.sessionRepository.getRecentSessions(limit: 5);
      final stats = await widget.sessionRepository.getSessionStatistics();
      if (!mounted) return;
      setState(() {
        _recentSessions = sessions;
        _stats = stats;
      });
    } catch (_) {
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nav = NavigationScope.of(context);

    // Resolve student display name
    String studentName = 'Student';
    try {
      final authCtrl = AuthScope.of(context);
      final fullName = authCtrl.currentUser?.fullName?.trim();
      if (fullName != null && fullName.isNotEmpty) {
        studentName = fullName.split(' ').first;
      }
    } catch (_) {}

    final totalMins = _stats['totalMinutes'] as int? ?? 0;
    final hours = totalMins ~/ 60;
    final mins = totalMins % 60;
    final formattedStudyTime = totalMins > 0 ? '${hours}h ${mins}m' : '0m';
    final avgFocus = _stats['averageFocusScore'] as int? ?? 0;
    final formattedFocus = avgFocus > 0 ? '$avgFocus%' : '0%';
    final sessionCount = _stats['completedSessionsCount'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Notion-Inspired Editorial Hero / Workspace Welcome
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Good morning',
                    style: AppTypography.displayMedium.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.8,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (studentName.isNotEmpty && studentName != 'Student') ...[
                    Text(
                      ', $studentName',
                      style: AppTypography.displayMedium.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.8,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.md),
                  const MentraBadge(
                    label: 'WORKSPACE ACTIVE',
                    variant: MentraBadgeVariant.success,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'What are you working on today?',
                style: AppTypography.bodyLarge.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Main Action Buttons
              Row(
                children: [
                  MentraButton(
                    label: 'Start Study Session',
                    icon: Icons.play_arrow_rounded,
                    onPressed: widget.onStartStudySession,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  MentraButton(
                    label: 'Ask Mentra AI',
                    icon: Icons.psychology_outlined,
                    variant: MentraButtonVariant.secondary,
                    onPressed: () => nav.setRoute(AppRoute.aiCoach),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  MentraButton(
                    label: 'Coursework',
                    icon: Icons.folder_outlined,
                    variant: MentraButtonVariant.ghost,
                    onPressed: () => nav.setRoute(AppRoute.subjects),
                  ),
                ],
              ),
            ],
          ),
        ),

        Divider(color: theme.dividerColor, height: 1),
        const SizedBox(height: AppSpacing.xl),

        // TODAY: Clean Metrics Row
        MentraSection(
          title: 'Today',
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
                  title: 'Sessions Completed',
                  value: '$sessionCount',
                  subtitle: 'Completed study blocks',
                  icon: Icons.check_circle_outline_rounded,
                  trendLabel: sessionCount > 0 ? 'Logged' : 'Ready',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // RECENT WORK & INSIGHT: Row Layout
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recent Sessions Table / List
            Expanded(
              flex: 3,
              child: MentraSection(
                title: 'Recent Work',
                subtitle: 'Completed study blocks & attention records',
                child: MentraCard(
                  padding: EdgeInsets.zero,
                  child: _recentSessions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 32,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'No study sessions completed yet.',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Start a focused block to see your progress here.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentSessions.length,
                          separatorBuilder: (_, _) => Divider(
                            color: theme.dividerColor,
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final session = _recentSessions[index];
                            return _RecentSessionRow(
                              session: session,
                              onTap: () {
                                if (session.subjectId != null && session.subjectId!.isNotEmpty) {
                                  widget.onOpenSubject(session.subjectId!);
                                }
                              },
                            );
                          },
                        ),
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.lg),

            // Mentra Insight & Quick Actions
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  MentraSection(
                    title: 'Mentra Insight',
                    subtitle: 'Cognitive behavioral pattern',
                    child: MentraCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: AppRadius.borderSm,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.psychology_outlined,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                _recentSessions.isEmpty ? 'Cognitive Baseline' : 'Focus Endurance',
                                style: AppTypography.labelMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _recentSessions.isEmpty
                                ? 'No study sessions recorded yet. Complete your first study block with on-device focus tracking to establish your real attention baseline.'
                                : 'Your average attention score across ${_recentSessions.length} logged session(s) is ${_stats['averageFocusScore'] ?? 0}%. Continue pacing 45-minute blocks for maximum retention.',
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextButton.icon(
                            onPressed: () => nav.setRoute(AppRoute.analytics),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                            label: const Text('View detailed progress'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: EdgeInsets.zero,
                              textStyle: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Quick Workspace Shortcuts
                  MentraCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Shortcuts',
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildShortcutRow(
                          icon: Icons.note_add_outlined,
                          label: 'Write lecture notes',
                          onTap: () => nav.setRoute(AppRoute.notes),
                          theme: theme,
                        ),
                        const SizedBox(height: 6),
                        _buildShortcutRow(
                          icon: Icons.flag_outlined,
                          label: 'Review goal milestones',
                          onTap: () => nav.setRoute(AppRoute.goals),
                          theme: theme,
                        ),
                        const SizedBox(height: 6),
                        _buildShortcutRow(
                          icon: Icons.tune_outlined,
                          label: 'Workspace preferences',
                          onTap: () => nav.setRoute(AppRoute.settings),
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShortcutRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSessionRow extends StatefulWidget {
  const _RecentSessionRow({
    required this.session,
    required this.onTap,
  });

  final StudySessionRecord session;
  final VoidCallback onTap;

  @override
  State<_RecentSessionRow> createState() => _RecentSessionRowState();
}

class _RecentSessionRowState extends State<_RecentSessionRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final session = widget.session;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _isHovered
              ? (isDark ? const Color(0xFF292927) : const Color(0xFFF7F7F5))
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2E28) : AppColors.primarySoft,
                        borderRadius: AppRadius.borderSm,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.topicTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${session.subjectTitle} • ${session.durationMinutes} min',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
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
        ),
      ),
    );
  }
}
