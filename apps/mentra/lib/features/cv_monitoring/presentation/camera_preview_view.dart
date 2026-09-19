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
    this.onObservation,
    this.onClose,
  });

  final String viewId;
  final bool isCompact;
  final bool showControls;
  final bool isAnimated;
  final FocusObservation? latestObservation;
  final void Function(FocusObservation observation)? onObservation;
  final VoidCallback? onClose;

  @override
  State<CameraPreviewView> createState() => _CameraPreviewViewState();
}

class _CameraPreviewViewState extends State<CameraPreviewView>
    with SingleTickerProviderStateMixin {
  bool _isCameraEnabled = true;
  bool _showCvOverlay = true;
  bool _showDiagnostics = false;
  bool _isMirrored = true;
  late final AnimationController _pulseController;

  // Real-time live CV Telemetry state from real camera feed
  RealTimeCvTelemetry _telemetry = RealTimeCvTelemetry.uninitialized();

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
    }
  }

  void _onLiveTelemetry(RealTimeCvTelemetry newTelemetry) {
    if (mounted) {
      setState(() {
        _telemetry = newTelemetry;
      });

      final now = DateTime.now();
      FocusObservation obs;

      if (!newTelemetry.isFaceDetected) {
        obs = FocusObservation(
          timestamp: now,
          isFaceDetected: false,
          faceConfidence: 0.0,
          ear: newTelemetry.ear,
          yaw: newTelemetry.yaw,
          pitch: newTelemetry.pitch,
          roll: newTelemetry.roll,
          focusState: 'FACE_NOT_DETECTED',
        );
      } else if (newTelemetry.phoneDetected) {
        // Real Phone Detected by local YOLO
        obs = FocusObservation(
          timestamp: now,
          isFaceDetected: true,
          faceBoundingBox: newTelemetry.box,
          faceConfidence: newTelemetry.confidence,
          eyeState: EyeState.open,
          isDistractionDetected: true,
          distractionConfidence: newTelemetry.phoneConfidence,
          distractionType: 'phone',
          phoneDetected: true,
          phoneConfidence: newTelemetry.phoneConfidence,
          ear: newTelemetry.ear,
          yaw: newTelemetry.yaw,
          pitch: newTelemetry.pitch,
          roll: newTelemetry.roll,
          focusState: 'PHONE_DETECTED',
        );
      } else if (newTelemetry.focusState == 'POSSIBLE_DROWSINESS' || newTelemetry.ear < 0.20) {
        // Real eye closure / drowsiness detected from real landmarks
        obs = FocusObservation(
          timestamp: now,
          isFaceDetected: true,
          faceBoundingBox: newTelemetry.box,
          faceConfidence: newTelemetry.confidence,
          eyeState: EyeState.closed,
          eyeOpenProbability: 0.05,
          ear: newTelemetry.ear,
          yaw: newTelemetry.yaw,
          pitch: newTelemetry.pitch,
          roll: newTelemetry.roll,
          focusState: 'POSSIBLE_DROWSINESS',
        );
      } else if (newTelemetry.orientation == 'LOOKING_AWAY' || newTelemetry.orientation == 'LOOKING_DOWN') {
        // Real head turned away or pitched downward
        obs = FocusObservation(
          timestamp: now,
          isFaceDetected: true,
          faceBoundingBox: newTelemetry.box,
          faceConfidence: newTelemetry.confidence,
          eyeState: EyeState.open,
          isDistractionDetected: true,
          distractionConfidence: 0.90,
          distractionType: newTelemetry.orientation == 'LOOKING_DOWN' ? 'looking_down' : 'looking_away',
          ear: newTelemetry.ear,
          yaw: newTelemetry.yaw,
          pitch: newTelemetry.pitch,
          roll: newTelemetry.roll,
          focusState: newTelemetry.orientation,
        );
      } else {
        // Real focused state
        obs = FocusObservation(
          timestamp: now,
          isFaceDetected: true,
          faceBoundingBox: newTelemetry.box,
          faceConfidence: newTelemetry.confidence,
          eyeState: EyeState.open,
          eyeOpenProbability: 0.95,
          ear: newTelemetry.ear,
          yaw: newTelemetry.yaw,
          pitch: newTelemetry.pitch,
          roll: newTelemetry.roll,
          focusState: 'FOCUSED',
        );
      }

      widget.onObservation?.call(obs);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
              ? (_telemetry.isFaceDetected
                  ? (_telemetry.statusMessage.contains('FOCUSED')
                      ? const Color(0xFF2EA043).withValues(alpha: 0.85)
                      : Colors.amberAccent.withValues(alpha: 0.90))
                  : Colors.orangeAccent.withValues(alpha: 0.90))
              : (isDark ? const Color(0xFF30363D) : const Color(0xFFE1E4E8)),
          width: 2.0,
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
          // 1. Live Camera Stream Platform View with Real-time Frame Analysis
          if (_isCameraEnabled)
            platform_camera.buildPlatformCameraView(
              viewId: widget.viewId,
              isMirrored: _isMirrored,
              onTelemetry: _onLiveTelemetry,
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

          // 2. Real-Time Dynamic Computer Vision HUD Overlay
          if (_isCameraEnabled && _showCvOverlay) ...[
            // Subtle scanner grid
            CustomPaint(
              painter: _CvHudGridPainter(pulseValue: _pulseController.value),
            ),

            // Live Dynamic Face Bounding Box & Landmarks
            LayoutBuilder(
              builder: (context, constraints) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _RealTimeFaceTrackingPainter(
                    telemetry: _telemetry,
                    pulseValue: _pulseController.value,
                    isCompact: widget.isCompact,
                  ),
                );
              },
            ),

            // Top HUD Telemetry Bar
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Align(
                alignment: Alignment.topLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: AppRadius.borderSm,
                          border: Border.all(
                            color: _telemetry.isFaceDetected
                                ? (_telemetry.statusMessage.contains('FOCUSED')
                                    ? const Color(0xFF238636)
                                    : Colors.amber)
                                : Colors.orange,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _telemetry.isFaceDetected
                                    ? (_telemetry.statusMessage.contains('FOCUSED')
                                        ? const Color(0xFF2EA043)
                                        : Colors.amberAccent)
                                    : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _telemetry.isFaceDetected
                                  ? (_telemetry.statusMessage.contains('FOCUSED')
                                      ? 'CV • ${_telemetry.fps} FPS'
                                      : _telemetry.statusMessage)
                                  : 'NO FACE DETECTED',
                              style: TextStyle(
                                color: _telemetry.isFaceDetected
                                    ? (_telemetry.statusMessage.contains('FOCUSED')
                                        ? const Color(0xFF7EE787)
                                        : Colors.amberAccent)
                                    : Colors.orangeAccent,
                                fontSize: 9.0,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!widget.isCompact) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
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
                                size: 10,
                                color: Colors.lightBlueAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '100% Local',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Real-Time CV Metrics Readout
            Positioned(
              bottom: widget.showControls ? 44 : 8,
              left: 8,
              right: 8,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: AppRadius.borderSm,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMetricChip(
                          label: 'ATTENTION',
                          value: '${(_telemetry.attentionScore * 100).toInt()}%',
                          color: _telemetry.attentionScore > 0.75
                              ? const Color(0xFF7EE787)
                              : (_telemetry.attentionScore > 0.4 ? Colors.amber : Colors.redAccent),
                        ),
                        const SizedBox(width: 10),
                        _buildMetricChip(
                          label: 'POSE (Y/P)',
                          value: '${_telemetry.yaw.toInt()}° / ${_telemetry.pitch.toInt()}°',
                          color: Colors.lightBlueAccent,
                        ),
                        const SizedBox(width: 10),
                        _buildMetricChip(
                          label: 'EAR',
                          value: _telemetry.ear.toStringAsFixed(2),
                          color: _telemetry.ear > 0.18 ? Colors.white70 : Colors.amber,
                        ),
                        if (!widget.isCompact) ...[
                          const SizedBox(width: 10),
                          _buildMetricChip(
                            label: 'STATUS',
                            value: _telemetry.isFaceDetected ? 'Tracked' : 'Absent',
                            color: _telemetry.isFaceDetected ? const Color(0xFF7EE787) : Colors.orange,
                          ),
                        ],
                      ],
                    ),
                  ),
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
                  const SizedBox(width: AppSpacing.xs),
                  _buildToolButton(
                    icon: Icons.bug_report_outlined,
                    tooltip: 'Developer CV Diagnostics',
                    isActive: _showDiagnostics,
                    onPressed: () => setState(() => _showDiagnostics = !_showDiagnostics),
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

          // 4. Developer / Debug Diagnostics View Overlay
          if (_showDiagnostics)
            Positioned(
              top: 42,
              left: 10,
              right: 10,
              child: _buildDiagnosticsOverlay(),
            ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsOverlay() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xEE090D13),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: const Color(0xFF388BFD), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal_rounded, size: 13, color: Color(0xFF58A6FF)),
                  SizedBox(width: 5),
                  Text(
                    'MENTRA CV DIAGNOSTICS (ON-DEVICE)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF58A6FF),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _showDiagnostics = false),
                child: const Icon(Icons.close, size: 13, color: Colors.white60),
              ),
            ],
          ),
          const Divider(height: 10, thickness: 0.8, color: Colors.white24),
          _buildDiagRow('Camera Feed', _isCameraEnabled ? 'READY (Browser getUserMedia)' : 'MUTED / OFF'),
          _buildDiagRow(
            'Face Presence',
            _telemetry.isFaceDetected
                ? 'DETECTED (${(_telemetry.confidence * 100).toInt()}% conf)'
                : 'ABSENT / NOT DETECTED',
            color: _telemetry.isFaceDetected ? const Color(0xFF7EE787) : Colors.orangeAccent,
          ),
          _buildDiagRow(
            'Eye Closure / EAR',
            '${_telemetry.ear < 0.20 ? "CLOSED" : "OPEN"} (EAR: ${_telemetry.ear.toStringAsFixed(3)} | L:${_telemetry.leftEar.toStringAsFixed(2)} R:${_telemetry.rightEar.toStringAsFixed(2)})',
            color: _telemetry.ear < 0.20 ? Colors.amberAccent : Colors.white70,
          ),
          _buildDiagRow(
            'Head Pose (Euler)',
            'Yaw: ${_telemetry.yaw > 0 ? "+" : ""}${_telemetry.yaw.toInt()}° | Pitch: ${_telemetry.pitch > 0 ? "+" : ""}${_telemetry.pitch.toInt()}° | Roll: ${_telemetry.roll.toInt()}°',
            color: Colors.lightBlueAccent,
          ),
          _buildDiagRow('Orientation', _telemetry.orientation),
          _buildDiagRow(
            'Phone Detection',
            _telemetry.phoneDetected
                ? 'DETECTED (${(_telemetry.phoneConfidence * 100).toInt()}% conf)'
                : 'NOT DETECTED (YOLOv8 Class 67)',
            color: _telemetry.phoneDetected ? Colors.redAccent : Colors.white70,
          ),
          _buildDiagRow(
            'Focus State',
            _telemetry.focusState,
            color: _telemetry.focusState == 'FOCUSED' ? const Color(0xFF7EE787) : Colors.amberAccent,
          ),
          _buildDiagRow(
            'Engine Telemetry',
            '${_telemetry.fps} FPS | Latency: ${_telemetry.latencyMs.toStringAsFixed(1)} ms',
            color: Colors.white60,
          ),
        ],
      ),
    );
  }

  Widget _buildDiagRow(String label, String value, {Color color = Colors.white70}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'monospace',
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
      ..color = const Color(0xFF58A6FF).withValues(alpha: 0.04 + pulseValue * 0.03)
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

class _RealTimeFaceTrackingPainter extends CustomPainter {
  const _RealTimeFaceTrackingPainter({
    required this.telemetry,
    required this.pulseValue,
    required this.isCompact,
  });

  final RealTimeCvTelemetry telemetry;
  final double pulseValue;
  final bool isCompact;

  @override
  void paint(Canvas canvas, Size size) {
    final isDetected = telemetry.isFaceDetected;
    final isDistracted = telemetry.statusMessage.contains('LOOKING') ||
        telemetry.statusMessage.contains('DROWSINESS') ||
        telemetry.statusMessage.contains('AWAY');

    final primaryColor = isDetected
        ? (isDistracted
            ? Colors.amberAccent.withValues(alpha: 0.90 + pulseValue * 0.10)
            : const Color(0xFF2EA043).withValues(alpha: 0.85 + pulseValue * 0.15))
        : Colors.orangeAccent.withValues(alpha: 0.85);

    final boxPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final landmarkPaint = Paint()
      ..color = isDetected
          ? (isDistracted ? Colors.amberAccent : const Color(0xFF58A6FF))
          : Colors.orangeAccent
      ..style = PaintingStyle.fill;

    final gazePaint = Paint()
      ..color = isDetected
          ? (isDistracted ? Colors.amber : const Color(0xFF388BFD))
          : Colors.orangeAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Convert normalized (0.0 - 1.0) coordinates to actual widget pixels
    final box = telemetry.box;
    final pixelRect = Rect.fromLTRB(
      box.left * size.width,
      box.top * size.height,
      box.right * size.width,
      box.bottom * size.height,
    );

    // Draw Corner Brackets on the Real Detected Face
    const cornerLen = 18.0;

    // Top-Left
    canvas.drawLine(Offset(pixelRect.left, pixelRect.top), Offset(pixelRect.left + cornerLen, pixelRect.top), boxPaint);
    canvas.drawLine(Offset(pixelRect.left, pixelRect.top), Offset(pixelRect.left, pixelRect.top + cornerLen), boxPaint);

    // Top-Right
    canvas.drawLine(Offset(pixelRect.right, pixelRect.top), Offset(pixelRect.right - cornerLen, pixelRect.top), boxPaint);
    canvas.drawLine(Offset(pixelRect.right, pixelRect.top), Offset(pixelRect.right, pixelRect.top + cornerLen), boxPaint);

    // Bottom-Left
    canvas.drawLine(Offset(pixelRect.left, pixelRect.bottom), Offset(pixelRect.left + cornerLen, pixelRect.bottom), boxPaint);
    canvas.drawLine(Offset(pixelRect.left, pixelRect.bottom), Offset(pixelRect.left, pixelRect.bottom - cornerLen), boxPaint);

    // Bottom-Right
    canvas.drawLine(Offset(pixelRect.right, pixelRect.bottom), Offset(pixelRect.right - cornerLen, pixelRect.bottom), boxPaint);
    canvas.drawLine(Offset(pixelRect.right, pixelRect.bottom), Offset(pixelRect.right, pixelRect.bottom - cornerLen), boxPaint);

    // Subtle Box Outline
    final r = RRect.fromRectAndRadius(pixelRect, const Radius.circular(8));
    canvas.drawRRect(
      r,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Draw Real-time Landmarks (Eyes, Nose, Mouth)
    for (int i = 0; i < telemetry.landmarks.length; i++) {
      final landmark = telemetry.landmarks[i];
      final pt = Offset(landmark.dx * size.width, landmark.dy * size.height);

      canvas.drawCircle(pt, i < 2 ? 3.5 : 2.5, landmarkPaint);

      // Eye crosshairs & gaze vector
      if (i < 2) {
        final gazeOffset = Offset(
          pt.dx + telemetry.yaw * 0.4,
          pt.dy + telemetry.pitch * 0.4,
        );
        canvas.drawLine(
          Offset(pt.dx - 8, pt.dy),
          Offset(pt.dx + 8, pt.dy),
          gazePaint,
        );
        canvas.drawLine(pt, gazeOffset, gazePaint);
      }
    }

    // Dynamic Tracking Tag Above Real-Time Bounding Box
    final tagText = isDetected
        ? (isDistracted
            ? telemetry.statusMessage
            : 'FACE TRACKED (${(telemetry.confidence * 100).toStringAsFixed(0)}%)')
        : 'AWAY FROM VIEW';

    final textSpan = TextSpan(
      text: tagText,
      style: TextStyle(
        color: isDetected
            ? (isDistracted ? Colors.amberAccent : const Color(0xFF7EE787))
            : Colors.orangeAccent,
        fontSize: isCompact ? 8.5 : 10.0,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        backgroundColor: Colors.black.withValues(alpha: 0.85),
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(pixelRect.left + 4, (pixelRect.top - textPainter.height - 4).clamp(8.0, size.height - 20)),
    );
  }

  @override
  bool shouldRepaint(covariant _RealTimeFaceTrackingPainter oldDelegate) =>
      oldDelegate.telemetry != telemetry ||
      oldDelegate.pulseValue != pulseValue;
}
