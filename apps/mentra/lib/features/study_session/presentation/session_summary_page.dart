import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_stat_card.dart';
import '../../ai_coach/domain/repositories/ai_coach_repository.dart';
import '../domain/models/study_session_record.dart';
import 'session_controller.dart';

class SessionSummaryPage extends StatefulWidget {
  const SessionSummaryPage({
    super.key,
    required this.sessionController,
    required this.onDone,
    this.aiCoachRepository,
  });

  final SessionController sessionController;
  final VoidCallback onDone;
  final AiCoachRepository? aiCoachRepository;

  @override
  State<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends State<SessionSummaryPage> {
  bool _isSaving = false;
  Map<String, dynamic>? _aiAnalysis;
  bool _isLoadingAiAnalysis = true;

  @override
  void initState() {
    super.initState();
    _loadAiAnalysis();
  }

  Future<void> _loadAiAnalysis() async {
    final repo = widget.aiCoachRepository;
    final config = widget.sessionController.currentConfig;
    final durationMins = (widget.sessionController.elapsedSeconds / 60).ceil();

    if (repo != null) {
      try {
        final analysis = await repo.analyzeSession(
          sessionId: 'sess_${DateTime.now().millisecondsSinceEpoch}',
          subjectTitle: config?.subjectTitle ?? 'General Subject',
          topicTitle: config?.topicTitle ?? 'General Topic',
          actualDurationMinutes: durationMins,
          targetDurationMinutes: config?.targetDurationMinutes ?? 45,
          focusScore: widget.sessionController.focusScore,
          distractionsCount: widget.sessionController.distractionsCount,
          reflection: widget.sessionController.selectedReflection.name,
        );
        if (mounted) {
          setState(() {
            _aiAnalysis = analysis;
            _isLoadingAiAnalysis = false;
          });
        }
        return;
      } catch (_) {
        // Fallback safely
      }
    }

    if (mounted) {
      setState(() => _isLoadingAiAnalysis = false);
    }
  }

  void _handleSave() async {
    setState(() => _isSaving = true);
    await widget.sessionController.saveCompletedSession();
    if (mounted) {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final config = widget.sessionController.currentConfig;
    final durationMins = (widget.sessionController.elapsedSeconds / 60).ceil();
    final focusScore = widget.sessionController.focusScore;
    final distractions = widget.sessionController.distractionsCount;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: MentraCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const MentraBadge(
                        label: 'SESSION COMPLETE',
                        variant: MentraBadgeVariant.success,
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      Text(
                        'Just now',
                        style: AppTypography.labelSmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  Text(
                    'Great work, focus achieved.',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${config?.subjectTitle ?? "Subject"} • ${config?.topicTitle ?? "Topic"}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // 3 Key Stats
                  Row(
                    children: [
                      Expanded(
                        child: MentraStatCard(
                          title: 'Duration',
                          value: '$durationMins min',
                          subtitle: 'Target: ${config?.targetDurationMinutes ?? 45}m',
                          icon: Icons.timer_outlined,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: MentraStatCard(
                          title: 'Focus Score',
                          value: '$focusScore%',
                          subtitle: focusScore >= 80 ? 'High Attention' : 'Moderate',
                          icon: Icons.insights_outlined,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: MentraStatCard(
                          title: 'Distractions',
                          value: '$distractions',
                          subtitle: distractions <= 2 ? 'Minimal' : 'Resolved',
                          icon: Icons.phone_android_outlined,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // AI Coach Session Feedback Box
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F8),
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.psychology_outlined, size: 18, color: AppColors.accent),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  'AI Coach Reflection',
                                  style: AppTypography.labelSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            if (_aiAnalysis != null)
                              MentraBadge(
                                label: _aiAnalysis!['focus_rating'] as String? ?? 'Strong',
                                variant: MentraBadgeVariant.primary,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (_isLoadingAiAnalysis)
                          Text(
                            'Synthesizing session focus feedback...',
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else ...[
                          Text(
                            _aiAnalysis?['overall_feedback'] as String? ??
                                'Solid study session with consistent pacing. You maintained strong focus across the main interval.',
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (_aiAnalysis?['recommended_next_action'] != null)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.success),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    'Next: ${_aiAnalysis!['recommended_next_action']}',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  Divider(color: theme.dividerColor, height: 1),
                  const SizedBox(height: AppSpacing.lg),

                  // Session Reflection Rating
                  Text(
                    'Session Reflection',
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'How did this study session feel?',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Reflection Choice Selector
                  Row(
                    children: [
                      _buildReflectionChoice(
                        reflection: SessionReflection.difficult,
                        label: 'Difficult',
                        icon: Icons.sentiment_dissatisfied_outlined,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildReflectionChoice(
                        reflection: SessionReflection.okay,
                        label: 'Okay',
                        icon: Icons.sentiment_neutral_outlined,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildReflectionChoice(
                        reflection: SessionReflection.good,
                        label: 'Good',
                        icon: Icons.sentiment_satisfied_outlined,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildReflectionChoice(
                        reflection: SessionReflection.excellent,
                        label: 'Excellent',
                        icon: Icons.sentiment_very_satisfied_outlined,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Save & Return Button
                  MentraButton(
                    label: 'Save & Return to Workspace',
                    icon: Icons.save_outlined,
                    fullWidth: true,
                    isLoading: _isSaving,
                    onPressed: _handleSave,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReflectionChoice({
    required SessionReflection reflection,
    required String label,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = widget.sessionController.selectedReflection == reflection;

    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => widget.sessionController.setReflection(reflection),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                  : (isDark ? const Color(0xFF222222) : const Color(0xFFF2F2F0)),
              borderRadius: AppRadius.borderMd,
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
