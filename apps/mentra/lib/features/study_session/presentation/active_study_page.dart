import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/dialogs/mentra_dialogs.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_button.dart';
import 'session_controller.dart';

class ActiveStudyPage extends StatelessWidget {
  const ActiveStudyPage({
    super.key,
    required this.sessionController,
  });

  final SessionController sessionController;

  void _confirmEnd(BuildContext context) async {
    final shouldEnd = await MentraConfirmDialog.show(
      context: context,
      title: 'End Study Session?',
      message: 'Your progress up to this point will be saved to your session analytics.',
      confirmLabel: 'End Session',
      cancelLabel: 'Keep Studying',
    );
    if (shouldEnd) {
      sessionController.endSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPaused = sessionController.state == SessionState.paused;
    final config = sessionController.currentConfig;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141414) : const Color(0xFFF9F9F8),
      body: SafeArea(
        child: Stack(
          children: [
            // Center Focus Area
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Subject and Topic Breadcrumb
                    Text(
                      config?.subjectTitle.toUpperCase() ?? 'DATA ANALYTICS',
                      style: AppTypography.labelSmall.copyWith(
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      config?.topicTitle ?? 'Correlation & Regression',
                      textAlign: TextAlign.center,
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // Big Calm Focus Timer Display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
                        borderRadius: AppRadius.borderXl,
                        border: Border.all(
                          color: isPaused
                              ? Colors.orange.withValues(alpha: 0.5)
                              : theme.dividerColor,
                          width: isPaused ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            sessionController.formattedRemainingTime,
                            style: AppTypography.displayLarge.copyWith(
                              fontSize: 72,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isPaused ? Colors.orange : AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                isPaused ? 'Paused' : 'Focused',
                                style: AppTypography.labelSmall.copyWith(
                                  color: isPaused ? Colors.orange : AppColors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text('•', style: AppTypography.labelSmall.copyWith(color: theme.dividerColor)),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'On-Device Monitoring',
                                style: AppTypography.labelSmall.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // Action Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isPaused)
                          MentraButton(
                            label: 'Resume Focus',
                            icon: Icons.play_arrow_rounded,
                            variant: MentraButtonVariant.primary,
                            onPressed: sessionController.resumeSession,
                          )
                        else
                          MentraButton(
                            label: 'Pause',
                            icon: Icons.pause_rounded,
                            variant: MentraButtonVariant.secondary,
                            onPressed: sessionController.pauseSession,
                          ),
                        const SizedBox(width: AppSpacing.base),
                        MentraButton(
                          label: 'End Session',
                          icon: Icons.stop_rounded,
                          variant: MentraButtonVariant.outline,
                          onPressed: () => _confirmEnd(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Top Status Bar
            Positioned(
              top: AppSpacing.lg,
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE8E8E6),
                          borderRadius: AppRadius.borderSm,
                        ),
                        child: Center(
                          child: Text(
                            'M',
                            style: AppTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text('MENTRA FOCUS', style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const MentraBadge(
                    label: 'LIVE SESSION',
                    variant: MentraBadgeVariant.success,
                    icon: Icons.circle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
