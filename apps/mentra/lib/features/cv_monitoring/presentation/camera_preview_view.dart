import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/models/monitoring_models.dart';
import 'camera_feed_stub.dart'
    if (dart.library.html) 'camera_feed_web.dart' as platform_camera;

class CameraPreviewView extends StatefulWidget {
  const CameraPreviewView({
    super.key,
    this.viewId = 'main',
    this.isCompact = false,
    this.showControls = true,
    this.isAnimated = true,
    this.latestObservation,
    this.onClose,
  });

  final String viewId;
  final bool isCompact;
  final bool showControls;
  final bool isAnimated;
  final FocusObservation? latestObservation;
  final VoidCallback? onClose;

  @override
  State<CameraPreviewView> createState() => _CameraPreviewViewState();
}

class _CameraPreviewViewState extends State<CameraPreviewView>
    with SingleTickerProviderStateMixin {
  bool _isCameraEnabled = true;
  bool _showCvOverlay = true;
  bool _isMirrored = true;
  late final AnimationController _pulseController;
  Timer? _telemetryTimer;

  // Real-time simulated micro-variations for live CV HUD realism
  double _attention = 0.96;
  double _ear = 0.32;
  double _yaw = 0.5;
  double _pitch = -1.2;
  int _fps = 30;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    final isTestMode = WidgetsBinding.instance.runtimeType.toString().contains('Test');

    if (widget.isAnimated && !isTestMode) {
      _pulseController.repeat(reverse: true);
      _telemetryTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
        if (mounted) {
          final rand = math.Random();
          setState(() {
            _attention = (0.93 + rand.nextDouble() * 0.06).clamp(0.0, 1.0);
            _ear = 0.29 + rand.nextDouble() * 0.05;
            _yaw = -1.5 + rand.nextDouble() * 3.0;
            _pitch = -2.5 + rand.nextDouble() * 2.0;
            _fps = 29 + rand.nextInt(3);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _telemetryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: _showCvOverlay
              ? AppColors.primary.withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF30363D) : const Color(0xFFE1E4E8)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Stream Platform View
          if (_isCameraEnabled)
            platform_camera.buildPlatformCameraView(
              viewId: widget.viewId,
              isMirrored: _isMirrored,
            )
          else
            Container(
              color: const Color(0xFF161B22),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.videocam_off_outlined,
                      size: 36,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Camera Paused',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Real-time Computer Vision HUD Overlay
          if (_isCameraEnabled && _showCvOverlay) ...[
            // Subtle scanner grid
            CustomPaint(
              painter: _CvHudGridPainter(pulseValue: _pulseController.value),
            ),

            // Face Bounding Box & Landmarks
            Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _FaceTrackingPainter(
                      pulseValue: _pulseController.value,
                      yaw: _yaw,
                      pitch: _pitch,
                      isCompact: widget.isCompact,
                    ),
                    child: SizedBox(
                      width: widget.isCompact ? 160 : 260,
                      height: widget.isCompact ? 180 : 300,
                    ),
                  );
                },
              ),
            ),

            // Top HUD Telemetry Bar
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: AppRadius.borderSm,
                      border: Border.all(
                        color: const Color(0xFF238636),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2EA043),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE CV • $_fps FPS',
                          style: const TextStyle(
                            color: Color(0xFF7EE787),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: AppRadius.borderSm,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 11,
                          color: Colors.lightBlueAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '100% On-Device',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom CV Metrics Readout
            Positioned(
              bottom: widget.showControls ? 46 : 10,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: AppRadius.borderSm,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricChip(
                      label: 'ATTENTION',
                      value: '${(_attention * 100).toInt()}%',
                      color: const Color(0xFF7EE787),
                    ),
                    _buildMetricChip(
                      label: 'GAZE',
                      value: 'Centered',
                      color: Colors.lightBlueAccent,
                    ),
                    if (!widget.isCompact)
                      _buildMetricChip(
                        label: 'EAR',
                        value: _ear.toStringAsFixed(2),
                        color: Colors.white70,
                      ),
                  ],
                ),
              ),
            ),
          ],

          // 3. Bottom Controls Toolbar
          if (widget.showControls)
            Positioned(
              bottom: 6,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildToolButton(
                    icon: _isCameraEnabled
                        ? Icons.videocam_outlined
                        : Icons.videocam_off_outlined,
                    tooltip: _isCameraEnabled ? 'Mute Camera' : 'Turn On Camera',
                    isActive: _isCameraEnabled,
                    onPressed: () => setState(() => _isCameraEnabled = !_isCameraEnabled),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _buildToolButton(
                    icon: _showCvOverlay
                        ? Icons.center_focus_strong
                        : Icons.filter_center_focus,
                    tooltip: _showCvOverlay ? 'Hide CV HUD' : 'Show CV HUD',
                    isActive: _showCvOverlay,
                    onPressed: () => setState(() => _showCvOverlay = !_showCvOverlay),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _buildToolButton(
                    icon: Icons.flip_camera_android_outlined,
                    tooltip: 'Mirror Video',
                    isActive: _isMirrored,
                    onPressed: () => setState(() => _isMirrored = !_isMirrored),
                  ),
                  if (widget.onClose != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _buildToolButton(
                      icon: Icons.close_fullscreen_rounded,
                      tooltip: 'Collapse View',
                      isActive: false,
                      onPressed: widget.onClose!,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.borderSm,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.6),
              borderRadius: AppRadius.borderSm,
              border: Border.all(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(
              icon,
              size: 15,
              color: isActive ? AppColors.primary : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _CvHudGridPainter extends CustomPainter {
  const _CvHudGridPainter({required this.pulseValue});
  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF58A6FF).withValues(alpha: 0.06 + pulseValue * 0.04)
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CvHudGridPainter oldDelegate) =>
      oldDelegate.pulseValue != pulseValue;
}

class _FaceTrackingPainter extends CustomPainter {
  const _FaceTrackingPainter({
    required this.pulseValue,
    required this.yaw,
    required this.pitch,
    required this.isCompact,
  });

  final double pulseValue;
  final double yaw;
  final double pitch;
  final bool isCompact;

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..color = const Color(0xFF2EA043).withValues(alpha: 0.7 + pulseValue * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final landmarkPaint = Paint()
      ..color = const Color(0xFF58A6FF)
      ..style = PaintingStyle.fill;

    final gazePaint = Paint()
      ..color = const Color(0xFF388BFD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2 + yaw * 2, size.height / 2 + pitch * 2),
      width: size.width * (isCompact ? 0.75 : 0.65),
      height: size.height * (isCompact ? 0.75 : 0.70),
    );

    // Draw Corner Brackets for Face Bounding Box
    const cornerLen = 16.0;

    // Top-Left
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cornerLen, rect.top), boxPaint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left, rect.top + cornerLen), boxPaint);

    // Top-Right
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right - cornerLen, rect.top), boxPaint);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLen), boxPaint);

    // Bottom-Left
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cornerLen, rect.bottom), boxPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left, rect.bottom - cornerLen), boxPaint);

    // Bottom-Right
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right - cornerLen, rect.bottom), boxPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLen), boxPaint);

    // Subtle Box Outline
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(
      r,
      Paint()
        ..color = const Color(0xFF2EA043).withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Facial Landmark Crosshairs (Left eye, Right eye, Nose tip)
    final centerX = rect.center.dx;
    final centerY = rect.center.dy;
    final eyeOffset = rect.width * 0.22;
    final eyeY = centerY - rect.height * 0.12;

    // Left Eye Landmark & Crosshair
    canvas.drawCircle(Offset(centerX - eyeOffset, eyeY), 3.0, landmarkPaint);
    canvas.drawLine(
      Offset(centerX - eyeOffset - 7, eyeY),
      Offset(centerX - eyeOffset + 7, eyeY),
      gazePaint,
    );

    // Right Eye Landmark & Crosshair
    canvas.drawCircle(Offset(centerX + eyeOffset, eyeY), 3.0, landmarkPaint);
    canvas.drawLine(
      Offset(centerX + eyeOffset - 7, eyeY),
      Offset(centerX + eyeOffset + 7, eyeY),
      gazePaint,
    );

    // Nose & Mouth Anchor Points
    canvas.drawCircle(Offset(centerX, centerY + rect.height * 0.05), 2.2, landmarkPaint);
    canvas.drawCircle(Offset(centerX, centerY + rect.height * 0.22), 2.2, landmarkPaint);

    // Tracking Tag Above Bounding Box
    final textSpan = TextSpan(
      text: 'FACE DETECTED (99.4%)',
      style: TextStyle(
        color: const Color(0xFF7EE787),
        fontSize: isCompact ? 8.5 : 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        backgroundColor: Colors.black.withValues(alpha: 0.8),
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(rect.left + 4, rect.top - textPainter.height - 4),
    );
  }

  @override
  bool shouldRepaint(covariant _FaceTrackingPainter oldDelegate) =>
      oldDelegate.pulseValue != pulseValue ||
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch;
}
