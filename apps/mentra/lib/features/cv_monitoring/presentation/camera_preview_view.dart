import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
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
  final bool _isCameraEnabled = true;
  final bool _showCvOverlay = true;
  bool _showDiagnostics = false;
  bool _isMirrored = true;
  late final AnimationController _pulseController;

  // Calibration state
  bool _isCalibrating = false;
  double _calibrationProgress = 0.0;
  String _calibrationMessage = '';
  CVBaseline? _baseline;

  // Real-time live CV Telemetry state from real camera feed
  RealTimeCvTelemetry _telemetry = RealTimeCvTelemetry.uninitialized();

  // Active dismissible alert
  String? _dismissedAlertId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    final isTestMode =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
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

      obs = FocusObservation(
        timestamp: now,
        isFaceDetected: newTelemetry.isFaceDetected,
        faceBoundingBox: newTelemetry.box,
        faceConfidence: newTelemetry.confidence,
        eyeState: newTelemetry.ear < 0.20 ? EyeState.closed : EyeState.open,
        eyeOpenProbability: (newTelemetry.ear / 0.30).clamp(0.0, 1.0),
        isDistractionDetected: newTelemetry.focusState == 'LOOKING_AWAY' ||
            newTelemetry.focusState == 'LOOKING_DOWN' ||
            newTelemetry.focusState == 'PHONE_DETECTED' ||
            newTelemetry.focusState == 'POSSIBLE_DROWSINESS',
        distractionConfidence: newTelemetry.phoneDetected
            ? newTelemetry.phoneConfidence
            : (newTelemetry.isFaceDetected ? 0.85 : 0.0),
        distractionType: newTelemetry.phoneDetected
            ? 'phone'
            : (newTelemetry.focusState == 'LOOKING_DOWN'
                ? 'looking_down'
                : (newTelemetry.focusState == 'LOOKING_AWAY'
                    ? 'looking_away'
                    : null)),
        phoneDetected: newTelemetry.phoneDetected,
        phoneConfidence: newTelemetry.phoneConfidence,
        phoneAvailable: newTelemetry.phoneAvailable,
        ear: newTelemetry.ear,
        yaw: newTelemetry.yaw,
        pitch: newTelemetry.pitch,
        roll: newTelemetry.roll,
        yawDeviation: newTelemetry.yawDeviation,
        pitchDeviation: newTelemetry.pitchDeviation,
        rollDeviation: newTelemetry.rollDeviation,
        focusState: newTelemetry.focusState,
        cameraQuality: newTelemetry.cameraQuality,
        confidenceLevel: newTelemetry.confidenceLevel,
      );

      widget.onObservation?.call(obs);
    }
  }

  void _onCalibrationProgress(double progress, String quality, String message) {
    if (mounted) {
      setState(() {
        _calibrationProgress = progress;
        _calibrationMessage = message;
      });

      if (progress >= 1.0) {
        _finishCalibration();
      }
    }
  }

  Future<void> _startCalibration() async {
    setState(() {
      _isCalibrating = true;
      _calibrationProgress = 0.0;
      _calibrationMessage = 'Hold still and look at screen...';
    });

    await platform_camera.CameraFeedWebHelper.startCalibration();
  }

  Future<void> _finishCalibration() async {
    final baseline =
        await platform_camera.CameraFeedWebHelper.finishCalibration();
    if (mounted) {
      setState(() {
        _isCalibrating = false;
        _baseline = baseline;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alertMsg = _getActiveAlertMessage();

    return ClipRRect(
      borderRadius: AppRadius.borderMd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Hardware Video Feed Canvas
          if (_isCameraEnabled)
            platform_camera.buildPlatformCameraView(
              viewId: widget.viewId,
              isMirrored: _isMirrored,
              onTelemetry: _onLiveTelemetry,
              onCalibrationProgress: _onCalibrationProgress,
              isCalibrating: _isCalibrating,
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
            CustomPaint(
              painter: _CvHudGridPainter(pulseValue: _pulseController.value),
            ),

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

            // Top Status Badges (Focus State + Camera Quality + Calibration Indicator)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusChip(),
                    const SizedBox(width: 6),
                    _buildQualityChip(),
                    const SizedBox(width: 6),
                    _buildCalibrationBadge(),
                  ],
                ),
              ),
            ),
          ],

          // 3. Camera Quality Warning Banner (if POOR)
          if (_telemetry.cameraQuality.status == 'POOR' && !_isCalibrating)
            Positioned(
              top: 40,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.90),
                  borderRadius: AppRadius.borderSm,
                  border: Border.all(color: Colors.amber.shade700, width: 1.2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.amber.shade400),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _telemetry.cameraQuality.userMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Calm User Alert Toast (Dismissible)
          if (alertMsg != null && !_isCalibrating)
            Positioned(
              bottom: widget.showControls ? 56 : 12,
              left: 12,
              right: 12,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.88),
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(
                      color: _telemetry.focusState == 'PHONE_DETECTED'
                          ? Colors.redAccent
                          : Colors.amberAccent,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _telemetry.focusState == 'PHONE_DETECTED'
                            ? Icons.phone_android
                            : (_telemetry.focusState == 'POSSIBLE_DROWSINESS'
                                ? Icons.bedtime_outlined
                                : Icons.visibility_outlined),
                        size: 14,
                        color: _telemetry.focusState == 'PHONE_DETECTED'
                            ? Colors.redAccent
                            : Colors.amberAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        alertMsg,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _dismissedAlertId = _telemetry.focusState;
                          });
                        },
                        child: const Icon(Icons.close, size: 13, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Calibration Overlay (When Calibrating)
          if (_isCalibrating)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.75),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              value: _calibrationProgress,
                              strokeWidth: 4,
                              color: const Color(0xFF2EA043),
                              backgroundColor: Colors.white12,
                            ),
                          ),
                          Text(
                            '${(_calibrationProgress * 3.0).toStringAsFixed(1)}s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Calibrating Sitting Posture...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _calibrationMessage.isNotEmpty
                            ? _calibrationMessage
                            : 'Sit normally and look at the screen',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. Live Metrics & Control Strip
          if (widget.showControls)
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: AppRadius.borderSm,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Metrics
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMetricChip(
                          label: 'EAR',
                          value: _telemetry.ear.toStringAsFixed(2),
                          color: _telemetry.ear < 0.20
                              ? Colors.amberAccent
                              : const Color(0xFF7EE787),
                        ),
                        const SizedBox(width: 12),
                        _buildMetricChip(
                          label: 'YAW DEV',
                          value:
                              '${_telemetry.yawDeviation > 0 ? "+" : ""}${_telemetry.yawDeviation.toInt()}°',
                          color: _telemetry.yawDeviation.abs() > 15
                              ? Colors.amberAccent
                              : const Color(0xFF58A6FF),
                        ),
                        const SizedBox(width: 12),
                        _buildMetricChip(
                          label: 'SCORE',
                          value: _telemetry.focusScore != null
                              ? '${_telemetry.focusScore}%'
                              : '--',
                          color: Colors.lightGreenAccent,
                        ),
                      ],
                    ),

                    // Controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToolButton(
                          icon: _baseline != null
                              ? Icons.center_focus_strong
                              : Icons.center_focus_weak,
                          tooltip: _baseline != null
                              ? 'Recalibrate Baseline'
                              : 'Calibrate Posture (3s)',
                          isActive: _baseline != null,
                          onPressed: _startCalibration,
                        ),
                        const SizedBox(width: 6),
                        _buildToolButton(
                          icon: Icons.analytics_outlined,
                          tooltip: 'Diagnostics',
                          isActive: _showDiagnostics,
                          onPressed: () {
                            setState(() {
                              _showDiagnostics = !_showDiagnostics;
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildToolButton(
                          icon: _isMirrored
                              ? Icons.flip_outlined
                              : Icons.flip_camera_android_outlined,
                          tooltip: 'Mirror Video',
                          isActive: _isMirrored,
                          onPressed: () {
                            setState(() {
                              _isMirrored = !_isMirrored;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 7. Full Diagnostics Modal Overlay
          if (_showDiagnostics)
            Positioned(
              top: 36,
              left: 8,
              right: 8,
              bottom: 48,
              child: _buildDiagnosticsOverlay(),
            ),
        ],
      ),
    );
  }

  String? _getActiveAlertMessage() {
    final state = _telemetry.focusState;
    if (_dismissedAlertId == state) return null;

    if (state == 'PHONE_DETECTED') {
      return 'Put the phone aside and get back to your session.';
    } else if (state == 'POSSIBLE_DROWSINESS') {
      return 'Take a short break if you need one.';
    } else if (state == 'LOOKING_AWAY') {
      return 'Eyes on the screen.';
    } else if (state == 'LOOKING_DOWN') {
      return 'Head tilted down. Keep eyes on study material.';
    } else if (state == 'FACE_NOT_DETECTED') {
      return "Make sure you're visible to the camera.";
    }
    return null;
  }

  Widget _buildStatusChip() {
    final isFace = _telemetry.isFaceDetected;
    final state = _telemetry.focusState;

    Color bg;
    Color border;
    String label;

    if (state == 'FOCUSED') {
      bg = const Color(0xFF2EA043);
      border = const Color(0xFF238636);
      label = 'FOCUSED • ${_telemetry.fps} FPS';
    } else if (state == 'LOOKING_AWAY' || state == 'LOOKING_DOWN') {
      bg = Colors.amber.shade700;
      border = Colors.amber.shade800;
      label = state == 'LOOKING_AWAY' ? 'LOOKING AWAY' : 'LOOKING DOWN';
    } else if (state == 'POSSIBLE_DROWSINESS') {
      bg = Colors.amber.shade800;
      border = Colors.amber.shade900;
      label = 'POSSIBLE DROWSINESS';
    } else if (state == 'PHONE_DETECTED') {
      bg = Colors.red.shade700;
      border = Colors.red.shade800;
      label = 'PHONE DETECTED';
    } else if (state == 'RECOVERING') {
      bg = Colors.blue.shade700;
      border = Colors.blue.shade800;
      label = 'RECOVERING...';
    } else if (state == 'FACE_NOT_DETECTED' || !isFace) {
      bg = Colors.orange.shade800;
      border = Colors.orange.shade900;
      label = 'FACE NOT DETECTED';
    } else {
      bg = Colors.grey.shade700;
      border = Colors.grey.shade800;
      label = state;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: bg,
              fontSize: 9.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityChip() {
    final status = _telemetry.cameraQuality.status;
    Color color;
    if (status == 'GOOD') {
      color = const Color(0xFF2EA043);
    } else if (status == 'FAIR') {
      color = Colors.amberAccent;
    } else if (status == 'POOR') {
      color = Colors.redAccent;
    } else {
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.camera_alt_outlined, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            'CAM: $status',
            style: TextStyle(
              color: color,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationBadge() {
    final hasBaseline = _telemetry.baselineActive || _baseline != null;
    return InkWell(
      onTap: _startCalibration,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: AppRadius.borderSm,
          border: Border.all(
            color: hasBaseline ? const Color(0xFF58A6FF) : Colors.orangeAccent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasBaseline ? Icons.check_circle : Icons.tune,
              size: 10,
              color: hasBaseline ? const Color(0xFF58A6FF) : Colors.orangeAccent,
            ),
            const SizedBox(width: 4),
            Text(
              hasBaseline ? 'CALIBRATED' : 'UNCALIBRATED',
              style: TextStyle(
                color: hasBaseline ? const Color(0xFF58A6FF) : Colors.orangeAccent,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticsOverlay() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.94),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'REAL-TIME CV TELEMETRY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              InkWell(
                onTap: () => setState(() => _showDiagnostics = false),
                child: const Icon(Icons.close, size: 14, color: Colors.white70),
              ),
            ],
          ),
          const Divider(height: 10, thickness: 0.8, color: Colors.white24),
          _buildDiagRow(
            'Camera Quality',
            '${_telemetry.cameraQuality.status} (Lum: ${_telemetry.cameraQuality.brightness.toInt()} | Face: ${(_telemetry.cameraQuality.faceSizeRatio * 100).toStringAsFixed(1)}%)',
            color: _telemetry.cameraQuality.status == 'GOOD'
                ? const Color(0xFF7EE787)
                : Colors.amberAccent,
          ),
          _buildDiagRow(
            'Quality Message',
            _telemetry.cameraQuality.userMessage,
            color: Colors.white70,
          ),
          _buildDiagRow(
            'Face Presence',
            _telemetry.isFaceDetected
                ? 'DETECTED (${(_telemetry.confidence * 100).toInt()}% conf - ${_telemetry.confidenceLevel})'
                : 'ABSENT / NOT DETECTED',
            color: _telemetry.isFaceDetected
                ? const Color(0xFF7EE787)
                : Colors.orangeAccent,
          ),
          _buildDiagRow(
            'Baseline Status',
            _telemetry.baselineActive || _baseline != null
                ? 'ACTIVE (Resting EAR: ${_baseline?.normalEar.toStringAsFixed(2) ?? "0.28"})'
                : 'UNCALIBRATED (Using defaults)',
            color: const Color(0xFF58A6FF),
          ),
          _buildDiagRow(
            'Eye EAR / State',
            '${_telemetry.ear.toStringAsFixed(3)} [${_telemetry.eyeState}] (L:${_telemetry.leftEar.toStringAsFixed(2)} R:${_telemetry.rightEar.toStringAsFixed(2)})',
            color: _telemetry.ear < 0.20 ? Colors.amberAccent : Colors.white70,
          ),
          _buildDiagRow(
            'Head Pose Angles',
            'Yaw: ${_telemetry.yaw.toInt()}° | Pitch: ${_telemetry.pitch.toInt()}° | Roll: ${_telemetry.roll.toInt()}°',
            color: Colors.white70,
          ),
          _buildDiagRow(
            'Baseline Deviations',
            'Yaw Dev: ${_telemetry.yawDeviation > 0 ? "+" : ""}${_telemetry.yawDeviation.toInt()}° | Pitch Dev: ${_telemetry.pitchDeviation > 0 ? "+" : ""}${_telemetry.pitchDeviation.toInt()}°',
            color: Colors.lightBlueAccent,
          ),
          _buildDiagRow(
            'Phone Detection',
            !_telemetry.phoneAvailable
                ? 'UNAVAILABLE'
                : (_telemetry.phoneDetected
                    ? 'DETECTED (${(_telemetry.phoneConfidence * 100).toInt()}%)'
                    : 'NOT DETECTED'),
            color: _telemetry.phoneDetected ? Colors.redAccent : Colors.white70,
          ),
          _buildDiagRow(
            'Focus State',
            _telemetry.focusState,
            color: _telemetry.focusState == 'FOCUSED'
                ? const Color(0xFF7EE787)
                : Colors.amberAccent,
          ),
          const Divider(height: 10, thickness: 0.8, color: Colors.white24),
          const Text(
            'OBSERVED SESSION DURATIONS',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          _buildDiagRow('Focused Time', _formatSecs(_telemetry.focusedDuration),
              color: const Color(0xFF7EE787)),
          _buildDiagRow(
              'Looking Away', _formatSecs(_telemetry.lookingAwayDuration)),
          _buildDiagRow(
              'Possible Drowsiness', _formatSecs(_telemetry.possibleDrowsinessDuration)),
          _buildDiagRow(
              'Face Not Detected', _formatSecs(_telemetry.faceNotDetectedDuration)),
          _buildDiagRow('Phone Detected', _formatSecs(_telemetry.phoneDetectedDuration)),
          _buildDiagRow('Unknown Duration', _formatSecs(_telemetry.unknownDuration),
              color: Colors.white38),
          _buildDiagRow(
            'True Focus Score',
            _telemetry.focusScore != null ? '${_telemetry.focusScore}%' : 'Not enough data',
            color: Colors.lightGreenAccent,
          ),
          _buildDiagRow(
            'Engine FPS / Latency',
            '${_telemetry.fps} FPS | Latency: ${_telemetry.latencyMs.toStringAsFixed(1)} ms',
            color: Colors.white60,
          ),
        ],
      ),
    );
  }

  String _formatSecs(double sec) {
    final s = sec.toInt();
    final m = s ~/ 60;
    final r = s % 60;
    return '${m}m ${r.toString().padLeft(2, "0")}s';
  }

  Widget _buildDiagRow(String label, String value,
      {Color color = Colors.white70}) {
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
      ..color =
          const Color(0xFF58A6FF).withValues(alpha: 0.04 + pulseValue * 0.03)
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
            : const Color(0xFF2EA043)
                .withValues(alpha: 0.85 + pulseValue * 0.15))
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

    final box = telemetry.box;
    final pixelRect = Rect.fromLTRB(
      box.left * size.width,
      box.top * size.height,
      box.right * size.width,
      box.bottom * size.height,
    );

    const cornerLen = 18.0;

    // Top-Left
    canvas.drawLine(Offset(pixelRect.left, pixelRect.top),
        Offset(pixelRect.left + cornerLen, pixelRect.top), boxPaint);
    canvas.drawLine(Offset(pixelRect.left, pixelRect.top),
        Offset(pixelRect.left, pixelRect.top + cornerLen), boxPaint);

    // Top-Right
    canvas.drawLine(Offset(pixelRect.right, pixelRect.top),
        Offset(pixelRect.right - cornerLen, pixelRect.top), boxPaint);
    canvas.drawLine(Offset(pixelRect.right, pixelRect.top),
        Offset(pixelRect.right, pixelRect.top + cornerLen), boxPaint);

    // Bottom-Left
    canvas.drawLine(Offset(pixelRect.left, pixelRect.bottom),
        Offset(pixelRect.left + cornerLen, pixelRect.bottom), boxPaint);
    canvas.drawLine(Offset(pixelRect.left, pixelRect.bottom),
        Offset(pixelRect.left, pixelRect.bottom - cornerLen), boxPaint);

    // Bottom-Right
    canvas.drawLine(Offset(pixelRect.right, pixelRect.bottom),
        Offset(pixelRect.right - cornerLen, pixelRect.bottom), boxPaint);
    canvas.drawLine(Offset(pixelRect.right, pixelRect.bottom),
        Offset(pixelRect.right, pixelRect.bottom - cornerLen), boxPaint);

    // Subtle Box Outline
    final r = RRect.fromRectAndRadius(pixelRect, const Radius.circular(8));
    canvas.drawRRect(
      r,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Landmarks
    for (int i = 0; i < telemetry.landmarks.length; i++) {
      final landmark = telemetry.landmarks[i];
      final pt = Offset(landmark.dx * size.width, landmark.dy * size.height);

      canvas.drawCircle(pt, i < 2 ? 3.5 : 2.5, landmarkPaint);

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

    // Dynamic Tag
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
      Offset(pixelRect.left + 4,
          (pixelRect.top - textPainter.height - 4).clamp(8.0, size.height - 20)),
    );
  }

  @override
  bool shouldRepaint(covariant _RealTimeFaceTrackingPainter oldDelegate) =>
      oldDelegate.telemetry != telemetry ||
      oldDelegate.pulseValue != pulseValue;
}
