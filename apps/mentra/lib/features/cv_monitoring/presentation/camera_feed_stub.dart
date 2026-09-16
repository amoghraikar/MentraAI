import 'package:flutter/material.dart';

/// Camera feed widget stub for non-web / testing environments
Widget buildPlatformCameraView({required String viewId, required bool isMirrored}) {
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
