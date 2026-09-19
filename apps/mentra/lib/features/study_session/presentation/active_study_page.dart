import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/dialogs/mentra_dialogs.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_logo.dart';
import '../../cv_monitoring/domain/models/monitoring_models.dart';
import '../../cv_monitoring/presentation/camera_preview_view.dart';
import 'session_controller.dart';

enum StudyViewMode {
  split,
  pip,
  cameraProminent,
  timerOnly,
}

class ActiveStudyPage extends StatefulWidget {
  const ActiveStudyPage({
    super.key,
    required this.sessionController,
  });

  final SessionController sessionController;

  @override
  State<ActiveStudyPage> createState() => _ActiveStudyPageState();
}

class _ActiveStudyPageState extends State<ActiveStudyPage> {
  StudyViewMode _viewMode = StudyViewMode.split;
  final bool _isCameraMuted = false;

  SessionController get sessionController => widget.sessionController;

  Future<bool> _confirmEnd(BuildContext context) async {
    final shouldEnd = await MentraConfirmDialog.show(
      context: context,
      title: 'End Study Session?',
      message: 'Your progress up to this point will be saved to your session analytics.',
      confirmLabel: 'End Session',
      cancelLabel: 'Keep Studying',
    );
    if (shouldEnd) {
      sessionController.endSession();
      return true;
    }
    return false;
  }

  String _getMonitoringLabel(MonitoringStatus status, bool isPaused) {
    if (isPaused) return 'Monitoring Paused';
    switch (status) {
      case MonitoringStatus.running:
        return 'On-Device CV Active';
      case MonitoringStatus.permissionDenied:
        return 'Camera Disabled (Timer Mode)';
      case MonitoringStatus.unavailable:
        return 'Camera Unavailable';
      case MonitoringStatus.error:
        return 'Monitoring Offline';
      default:
        return 'On-Device Monitoring';
    }
  }

  Color _getMonitoringStatusColor(MonitoringStatus status, bool isPaused) {
    if (isPaused) return Colors.orange;
    switch (status) {
      case MonitoringStatus.running:
        return AppColors.success;
      case MonitoringStatus.permissionDenied:
      case MonitoringStatus.unavailable:
      case MonitoringStatus.error:
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sessionController,
      builder: (context, _) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final isPaused = sessionController.state == SessionState.paused;
        final config = sessionController.currentConfig;
        final alertEvent = sessionController.latestAlertEvent;
        final monitoringStatus = sessionController.monitoringStatus;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _confirmEnd(context);
            }
          },
          child: Scaffold(
            backgroundColor: isDark ? const Color(0xFF12151A) : const Color(0xFFF7F8FA),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;

                  return Stack(
                    children: [
                      // Main Body Area
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 64, bottom: 20, left: 24, right: 24),
                          child: isWide && _viewMode == StudyViewMode.split
                              ? _buildWideSplitLayout(context, theme, isDark, isPaused, config, alertEvent, monitoringStatus)
                              : _buildSingleColumnLayout(context, theme, isDark, isPaused, config, alertEvent, monitoringStatus, isWide),
                        ),
                      ),

                  // Floating PiP Camera (when in PiP mode)
                  if (_viewMode == StudyViewMode.pip && !_isCameraMuted)
                    Positioned(
                      bottom: 24,
                      right: 24,
                      width: 240,
                      height: 180,
                      child: CameraPreviewView(
                        viewId: 'active-pip',
                        isCompact: true,
                        showControls: true,
                        onObservation: sessionController.ingestObservation,
                        onClose: () => setState(() => _viewMode = StudyViewMode.split),
                      ),
                    ),

                  // Top Navigation & Status Bar
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.xl,
                    right: AppSpacing.xl,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const MentraBrandMark(size: 26),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'MENTRA FOCUS & CV ENGINE',
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // View Switcher Buttons
                            _buildViewModeToggle(
                              icon: Icons.splitscreen_rounded,
                              tooltip: 'Split View (Timer & Face CV)',
                              mode: StudyViewMode.split,
                            ),
                            const SizedBox(width: 4),
                            _buildViewModeToggle(
                              icon: Icons.picture_in_picture_alt_rounded,
                              tooltip: 'PiP Mode (Corner Camera)',
                              mode: StudyViewMode.pip,
                            ),
                            const SizedBox(width: 4),
                            _buildViewModeToggle(
                              icon: Icons.videocam_rounded,
                              tooltip: 'Focus on Face & CV Feed',
                              mode: StudyViewMode.cameraProminent,
                            ),
                            const SizedBox(width: 4),
                            _buildViewModeToggle(
                              icon: Icons.timer_outlined,
                              tooltip: 'Timer Only',
                              mode: StudyViewMode.timerOnly,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            const MentraBadge(
                              label: 'LIVE SESSION',
                              variant: MentraBadgeVariant.success,
                              icon: Icons.circle,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildViewModeToggle({
    required IconData icon,
    required String tooltip,
    required StudyViewMode mode,
  }) {
    final isActive = _viewMode == mode;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _viewMode = mode),
          borderRadius: AppRadius.borderSm,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: AppRadius.borderSm,
              border: Border.all(
                color: isActive ? AppColors.primary : Colors.transparent,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isActive ? AppColors.primary : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideSplitLayout(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    bool isPaused,
    dynamic config,
    FocusEvent? alertEvent,
    MonitoringStatus monitoringStatus,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: Timer, Goals, Controls
        Expanded(
          flex: 5,
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (alertEvent != null) ...[
                      _buildAlertBanner(context, alertEvent, theme, isDark),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    _buildSubjectHeader(theme, config),
                    const SizedBox(height: AppSpacing.xl),
                    _buildTimerCard(theme, isDark, isPaused, monitoringStatus),
                    const SizedBox(height: AppSpacing.xl),
                    _buildActionControls(context, isPaused),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xl),
        // Right Column: Live Real-Time Camera CV View
        Expanded(
          flex: 6,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
              child: CameraPreviewView(
                viewId: 'active-split',
                isCompact: false,
                showControls: true,
                onObservation: sessionController.ingestObservation,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleColumnLayout(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    bool isPaused,
    dynamic config,
    FocusEvent? alertEvent,
    MonitoringStatus monitoringStatus,
    bool isWide,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (alertEvent != null) ...[
                _buildAlertBanner(context, alertEvent, theme, isDark),
                const SizedBox(height: AppSpacing.lg),
              ],
              _buildSubjectHeader(theme, config),
              const SizedBox(height: AppSpacing.lg),

              // If Camera Prominent, show Camera on top!
              if (_viewMode == StudyViewMode.cameraProminent) ...[
                SizedBox(
                  height: 320,
                  width: double.infinity,
                  child: CameraPreviewView(
                    viewId: 'active-prominent',
                    isCompact: false,
                    showControls: true,
                    onObservation: sessionController.ingestObservation,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Main Timer Card
              _buildTimerCard(theme, isDark, isPaused, monitoringStatus),

              // If Split on mobile / single column, show Camera below timer
              if (_viewMode == StudyViewMode.split && !isWide) ...[
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: CameraPreviewView(
                    viewId: 'active-mobile-split',
                    isCompact: true,
                    showControls: true,
                    onObservation: sessionController.ingestObservation,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
              _buildActionControls(context, isPaused),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectHeader(ThemeData theme, dynamic config) {
    return Column(
      children: [
        Text(
          config?.subjectTitle.toUpperCase() ?? 'ACTIVE STUDY TOPIC',
          style: AppTypography.labelSmall.copyWith(
            letterSpacing: 2.0,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          config?.topicTitle ?? 'Focused Study Session',
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildTimerCard(
    ThemeData theme,
    bool isDark,
    bool isPaused,
    MonitoringStatus monitoringStatus,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
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
              fontSize: 68,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              height: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Builder(
            builder: (context) {
              String statusText;
              Color statusColor;

              final alert = sessionController.latestAlertEvent;
              if (isPaused) {
                statusText = 'Paused';
                statusColor = Colors.orange;
              } else if (monitoringStatus == MonitoringStatus.permissionDenied) {
                statusText = 'Camera Off';
                statusColor = Colors.grey;
              } else if (monitoringStatus == MonitoringStatus.unavailable ||
                  monitoringStatus == MonitoringStatus.error) {
                statusText = 'CV Offline';
                statusColor = Colors.grey;
              } else if (alert?.type == FocusEventType.faceAbsent) {
                statusText = 'Away';
                statusColor = Colors.orangeAccent;
              } else if (alert != null) {
                statusText = 'Distracted';
                statusColor = Colors.amberAccent;
              } else {
                statusText = 'Focused';
                statusColor = AppColors.success;
              }

              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      statusText,
                      style: AppTypography.labelSmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('•', style: AppTypography.labelSmall.copyWith(color: theme.dividerColor)),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Score: ${sessionController.focusScore}%',
                      style: AppTypography.labelSmall.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('•', style: AppTypography.labelSmall.copyWith(color: theme.dividerColor)),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _getMonitoringLabel(monitoringStatus, isPaused),
                      style: AppTypography.labelSmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionControls(BuildContext context, bool isPaused) {
    return Row(
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
    );
  }

  Widget _buildAlertBanner(
    BuildContext context,
    FocusEvent event,
    ThemeData theme,
    bool isDark,
  ) {
    String title;
    String message;
    IconData icon;

    switch (event.type) {
      case FocusEventType.drowsinessDetected:
        title = 'Drowsiness Detected';
        message = 'Prolonged eye closure observed. Stretch or take a sip of water.';
        icon = Icons.bedtime_outlined;
        break;
      case FocusEventType.distractionDetected:
        final distrType = event.metadata['distraction_type'] as String?;
        if (distrType == 'looking_down') {
          title = 'Phone / Desk Distraction';
          message = 'Gaze directed downward. Refocus on your active study topic.';
        } else {
          title = 'Head Turned / Looking Away';
          message = 'Gaze directed away from study screen. Refocus on your material.';
        }
        icon = Icons.visibility_off_outlined;
        break;
      case FocusEventType.faceAbsent:
        title = 'Away from Study View';
        message = 'No face detected in camera view. Session timer continues.';
        icon = Icons.person_off_outlined;
        break;
      default:
        title = 'Focus Notice';
        message = event.message ?? 'Stay on track.';
        icon = Icons.notifications_none_outlined;
        break;
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A241E) : const Color(0xFFFFF8E6),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber[700], size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.amber[200] : Colors.amber[900],
                  ),
                ),
                Text(
                  message,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 12,
                    color: isDark ? Colors.amber[100] : Colors.amber[800],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: isDark ? Colors.amber[200] : Colors.amber[900],
            onPressed: sessionController.dismissLatestAlert,
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}
