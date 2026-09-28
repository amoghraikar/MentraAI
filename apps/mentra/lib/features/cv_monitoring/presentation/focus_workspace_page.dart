import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_page_header.dart';
import '../../../shared/widgets/mentra_section.dart';
import '../../../shared/widgets/mentra_stat_card.dart';
import '../../study_session/presentation/session_controller.dart';
import '../domain/models/monitoring_models.dart';
import 'camera_preview_view.dart';

class FocusWorkspacePage extends StatefulWidget {
  const FocusWorkspacePage({
    super.key,
    required this.sessionController,
    required this.onStartSession,
  });

  final SessionController sessionController;
  final VoidCallback onStartSession;

  @override
  State<FocusWorkspacePage> createState() => _FocusWorkspacePageState();
}

class _FocusWorkspacePageState extends State<FocusWorkspacePage> {
  bool _previewCamera = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ctrl = widget.sessionController;

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final isSessionActive =
            ctrl.state == SessionState.active || ctrl.state == SessionState.paused;
        final isPaused = ctrl.state == SessionState.paused;
        final config = ctrl.currentConfig;
        final score = ctrl.focusScore;
        final alert = ctrl.latestAlertEvent;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MentraPageHeader(
              title: 'Focus & CV Engine',
              subtitle: 'On-device private computer vision monitoring for study attention and cognitive endurance',
              action: MentraButton(
                label: isSessionActive ? 'Open Live Session' : 'Start Focus Session',
                icon: isSessionActive ? Icons.fullscreen_rounded : Icons.play_arrow_rounded,
                onPressed: widget.onStartSession,
              ),
            ),

            // Top Status Banner
            if (isSessionActive)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: MentraCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderColor: isPaused ? AppColors.warning : AppColors.primary,
                  backgroundColor: isPaused
                      ? (isDark ? const Color(0xFF2E2214) : AppColors.warningSubtle)
                      : (isDark ? const Color(0xFF162822) : AppColors.primarySoft),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isPaused ? AppColors.warning : AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          isPaused
                              ? 'Active study session is paused. Resume to continue on-device focus tracking.'
                              : 'Live focus tracking active: ${config?.subjectTitle ?? "General"} • ${config?.topicTitle ?? ""}',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (isPaused)
                        MentraButton(
                          label: 'Resume Focus',
                          variant: MentraButtonVariant.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          onPressed: ctrl.resumeSession,
                        )
                      else
                        MentraButton(
                          label: 'Pause',
                          variant: MentraButtonVariant.secondary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          onPressed: ctrl.pauseSession,
                        ),
                    ],
                  ),
                ),
              ),

            // Telemetry Stat Cards
            Row(
              children: [
                Expanded(
                  child: MentraStatCard(
                    title: 'Current Focus Score',
                    value: '$score%',
                    subtitle: score >= 80
                        ? 'High cognitive engagement'
                        : (score > 0 ? 'Moderate attention baseline' : 'Calculated in real-time'),
                    icon: Icons.speed_rounded,
                    iconColor: score >= 80 ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MentraStatCard(
                    title: 'Session Duration',
                    value: isSessionActive
                        ? ctrl.formattedElapsedTime
                        : '${config?.targetDurationMinutes ?? 45} min target',
                    subtitle: isSessionActive ? 'Active elapsed time' : 'Default session block',
                    icon: Icons.timer_outlined,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MentraStatCard(
                    title: 'CV Engine Telemetry',
                    value: _getEngineStatus(ctrl.monitoringStatus),
                    subtitle: 'Local on-device inference (0 cloud upload)',
                    icon: Icons.camera_alt_outlined,
                    iconColor: ctrl.monitoringStatus == MonitoringStatus.running
                        ? AppColors.success
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // Two-column layout: Camera Preview & State Telemetry
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Camera Viewport / Diagnostic Preview
                Expanded(
                  flex: 3,
                  child: MentraSection(
                    title: 'Vision Sensor Viewport',
                    subtitle: 'Visual proof of real-time face presence & head pose tracking',
                    child: MentraCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: AppRadius.borderMd,
                            child: Container(
                              height: 320,
                              width: double.infinity,
                              color: isDark ? const Color(0xFF141412) : const Color(0xFFEFEFEA),
                              child: _previewCamera || isSessionActive
                                  ? CameraPreviewView(
                                      viewId: 'focus-workspace-preview',
                                      isCompact: false,
                                      showControls: true,
                                      onObservation: ctrl.ingestObservation,
                                      onClose: () => setState(() => _previewCamera = false),
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.videocam_outlined,
                                            size: 40,
                                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                          ),
                                          const SizedBox(height: AppSpacing.sm),
                                          Text(
                                            'Camera stream is currently idle',
                                            style: AppTypography.bodySmall.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            'Local computer vision processes strictly in your browser.',
                                            style: AppTypography.bodySmall.copyWith(
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          MentraButton(
                                            label: 'Preview Camera Sensor',
                                            icon: Icons.videocam_rounded,
                                            variant: MentraButtonVariant.secondary,
                                            onPressed: () => setState(() => _previewCamera = true),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const MentraBadge(
                                    label: '100% PRIVATE',
                                    variant: MentraBadgeVariant.success,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    'No frames or video ever leave your device',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              if (_previewCamera && !isSessionActive)
                                TextButton.icon(
                                  onPressed: () => setState(() => _previewCamera = false),
                                  icon: const Icon(Icons.videocam_off_rounded, size: 16),
                                  label: const Text('Stop Preview'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: AppSpacing.lg),

                // Right Column: Focus States & Telemetry Breakdown
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      MentraSection(
                        title: 'Focus States',
                        subtitle: 'Real-time telemetry indicators',
                        child: MentraCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatusRow(
                                'Focused',
                                'Direct attention on coursework material',
                                AppColors.success,
                                score >= 80,
                                theme,
                              ),
                              const Divider(height: 16),
                              _buildStatusRow(
                                'Possible Distraction',
                                'Looking away or brief posture change',
                                AppColors.warning,
                                score >= 50 && score < 80,
                                theme,
                              ),
                              const Divider(height: 16),
                              _buildStatusRow(
                                'Distracted',
                                'Phone use or extended gaze absence',
                                AppColors.error,
                                score < 50 && isSessionActive,
                                theme,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (alert != null)
                        MentraCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          borderColor: AppColors.warning,
                          backgroundColor: isDark
                              ? const Color(0xFF2B2215)
                              : AppColors.warningSubtle,
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 18, color: AppColors.warning),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  alert.message ?? 'Attention shift detected',
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
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
      },
    );
  }

  Widget _buildStatusRow(
    String label,
    String description,
    Color color,
    bool isActive,
    ThemeData theme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isActive ? color : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: AppRadius.borderSm,
                      ),
                      child: Text(
                        'CURRENT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getEngineStatus(MonitoringStatus status) {
    switch (status) {
      case MonitoringStatus.running:
        return 'Active';
      case MonitoringStatus.permissionDenied:
        return 'Permission Denied';
      case MonitoringStatus.unavailable:
        return 'Ready (Idle)';
      case MonitoringStatus.error:
        return 'Error';
      default:
        return 'Ready';
    }
  }
}
