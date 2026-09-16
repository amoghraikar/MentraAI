import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../cv_monitoring/domain/models/monitoring_models.dart';
import '../../cv_monitoring/presentation/camera_preview_view.dart';
import 'session_controller.dart';

class StudyPrepPage extends StatelessWidget {
  const StudyPrepPage({
    super.key,
    required this.sessionController,
    required this.onStartSession,
    required this.onCancel,
  });

  final SessionController sessionController;
  final VoidCallback onStartSession;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final config = sessionController.currentConfig;
    final monitoringStatus = sessionController.monitoringStatus;

    if (config == null) {
      return Center(
        child: MentraButton(
          label: 'Back to Workspace',
          onPressed: onCancel,
        ),
      );
    }

    final isCameraDenied = monitoringStatus == MonitoringStatus.permissionDenied;
    final isCameraUnavailable = monitoringStatus == MonitoringStatus.unavailable;
    final cameraStatusLabel = isCameraDenied
        ? 'Disabled (Timer Mode)'
        : (isCameraUnavailable ? 'Unavailable' : 'Ready');
    final isCameraGood = !isCameraDenied && !isCameraUnavailable;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: MentraCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Back Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Cancel Setup'),
                        onPressed: onCancel,
                      ),
                      const MentraBadge(
                        label: 'PREPARATION',
                        variant: MentraBadgeVariant.primary,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  Text(
                    "You're ready.",
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Review session parameters before starting',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Session Parameter Summary Card
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
                        Text(
                          config.subjectTitle,
                          style: AppTypography.labelSmall.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          config.topicTitle,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Divider(color: theme.dividerColor, height: 1),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoItem(
                              context: context,
                              label: 'DURATION',
                              value: '${config.targetDurationMinutes} minutes',
                              icon: Icons.timer_outlined,
                            ),
                            _buildInfoItem(
                              context: context,
                              label: 'MODE',
                              value: config.studyMode,
                              icon: Icons.tune_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Live Camera Alignment & CV Check Preview
                  if (isCameraGood) ...[
                    Text(
                      'CAMERA ALIGNMENT & CV CHECK',
                      style: AppTypography.labelSmall.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: AppRadius.borderMd,
                      child: const SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: CameraPreviewView(
                          viewId: 'prep',
                          isCompact: true,
                          showControls: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Privacy & Hardware Check Indicators
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F8),
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      children: [
                        _buildStatusRow(
                          label: 'Local Camera Permission',
                          status: cameraStatusLabel,
                          isGood: isCameraGood,
                          icon: Icons.videocam_outlined,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildStatusRow(
                          label: 'Focus Telemetry Engine',
                          status: 'Active (On-Device)',
                          isGood: true,
                          icon: Icons.shield_outlined,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildStatusRow(
                          label: 'Microphone Audio',
                          status: 'Not required',
                          isGood: true,
                          icon: Icons.mic_off_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Start Session CTA
                  MentraButton(
                    label: 'Start Session',
                    icon: Icons.play_arrow_rounded,
                    fullWidth: true,
                    onPressed: onStartSession,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.labelSmall.copyWith(fontSize: 10)),
            Text(value, style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusRow({
    required String label,
    required String status,
    required bool isGood,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isGood ? AppColors.success : Colors.orange),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: AppTypography.bodySmall),
        ),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isGood ? AppColors.success : Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              status,
              style: AppTypography.labelSmall.copyWith(
                color: isGood ? AppColors.success : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
