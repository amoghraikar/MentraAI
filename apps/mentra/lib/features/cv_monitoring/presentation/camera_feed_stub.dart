import 'package:flutter/material.dart';
import '../domain/models/monitoring_models.dart';

/// Helper stub for non-web environments.
class CameraFeedWebHelper {
  static Future<bool> startCalibration() async => true;
  static Future<CVBaseline?> finishCalibration() async => null;
  static Future<void> pauseMonitoring() async {}
  static Future<void> resumeMonitoring() async {}
  static Future<void> resetSession() async {}
}

/// Stub camera feed widget for non-web / testing environments
Widget buildPlatformCameraView({
  required String viewId,
  required bool isMirrored,
  void Function(RealTimeCvTelemetry telemetry)? onTelemetry,
  void Function(double progress, String quality, String message)? onCalibrationProgress,
  bool isCalibrating = false,
}) {
  return Container(
    color: const Color(0xFF101418),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 40,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Live Camera Vision Feed',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
