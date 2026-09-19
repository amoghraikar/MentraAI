// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, unnecessary_cast
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import '../domain/models/monitoring_models.dart';

/// Web implementation of live camera feed using HTML5 VideoElement, getUserMedia,
/// and local MediaPipe + YOLO on-device Computer Vision Engine via backend endpoint.
Widget buildPlatformCameraView({
  required String viewId,
  required bool isMirrored,
  void Function(RealTimeCvTelemetry telemetry)? onTelemetry,
}) {
  return _WebCameraPlayer(
    viewId: viewId,
    isMirrored: isMirrored,
    onTelemetry: onTelemetry,
  );
}

class _WebCameraPlayer extends StatefulWidget {
  const _WebCameraPlayer({
    required this.viewId,
    required this.isMirrored,
    this.onTelemetry,
  });

  final String viewId;
  final bool isMirrored;
  final void Function(RealTimeCvTelemetry telemetry)? onTelemetry;

  @override
  State<_WebCameraPlayer> createState() => _WebCameraPlayerState();
}

class _WebCameraPlayerState extends State<_WebCameraPlayer> {
  html.VideoElement? _videoElement;
  html.CanvasElement? _offscreenCanvas;
  html.CanvasRenderingContext2D? _canvasCtx;
  Timer? _cvProcessingTimer;

  bool _isRegistered = false;
  bool _isProcessingFrame = false;
  late final String _elementId;

  static const String _cvEndpoint = 'http://127.0.0.1:8000/api/v1/cv/process-frame';

  // Real-time smoothed telemetry state
  double _smoothMinX = 0.25;
  double _smoothMinY = 0.18;
  double _smoothMaxX = 0.75;
  double _smoothMaxY = 0.76;
  int _lastClientFrameTime = 0;
  int _clientFrameCount = 0;
  int _clientFps = 0;

  @override
  void initState() {
    super.initState();
    _elementId = 'mentra-webcam-${widget.viewId}-${DateTime.now().millisecondsSinceEpoch}';
    _offscreenCanvas = html.CanvasElement(width: 320, height: 240);
    _canvasCtx = _offscreenCanvas!.context2D;
    _initWebcam();
  }

  void _initWebcam() {
    _videoElement = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.transform = widget.isMirrored ? 'scaleX(-1)' : 'none';

    // Register view factory with Flutter Web platformViewRegistry
    ui_web.platformViewRegistry.registerViewFactory(
      _elementId,
      (int id) => _videoElement!,
    );
    _isRegistered = true;

    // Request real hardware camera access via browser mediaDevices
    html.window.navigator.mediaDevices?.getUserMedia({'video': true}).then((stream) {
      if (mounted && _videoElement != null) {
        _videoElement!.srcObject = stream;
        _videoElement!.play();
        _startRealTimeCvPipeline();
      }
    }).catchError((error) {
      if (mounted) {
        widget.onTelemetry?.call(
          RealTimeCvTelemetry(
            isFaceDetected: false,
            confidence: 0.0,
            box: const Rect.fromLTWH(0.25, 0.20, 0.50, 0.55),
            landmarks: const [],
            yaw: 0.0,
            pitch: 0.0,
            roll: 0.0,
            attentionScore: 0.0,
            ear: 0.0,
            leftEar: 0.0,
            rightEar: 0.0,
            phoneDetected: false,
            phoneConfidence: 0.0,
            orientation: 'UNKNOWN',
            focusState: 'CAMERA_ERROR',
            fps: 0,
            latencyMs: 0.0,
            statusMessage: 'CAMERA PERMISSION DENIED / UNAVAILABLE',
          ),
        );
      }
    });
  }

  void _startRealTimeCvPipeline() {
    _cvProcessingTimer?.cancel();
    _lastClientFrameTime = DateTime.now().millisecondsSinceEpoch;

    // Run throttled frame capture loop every 120ms (~8 FPS)
    // Non-blocking: skips frame if prior frame inference is in progress
    _cvProcessingTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      _processLiveCameraFrame();
    });
  }

  Future<void> _processLiveCameraFrame() async {
    if (!mounted || _isProcessingFrame) return;
    if (_videoElement == null || _canvasCtx == null || _offscreenCanvas == null) return;
    if (_videoElement!.readyState < 2 || _videoElement!.videoWidth == 0) return;

    _isProcessingFrame = true;
    final startTime = DateTime.now().millisecondsSinceEpoch;

    try {
      // 1. Grab live frame from HTML5 video element into offscreen canvas (320x240)
      const cvWidth = 320;
      const cvHeight = 240;
      _canvasCtx!.drawImageScaled(_videoElement!, 0, 0, cvWidth, cvHeight);

      // Convert canvas to JPEG data URL
      final dataUrl = _offscreenCanvas!.toDataUrl('image/jpeg', 0.65);

      final now = DateTime.now().millisecondsSinceEpoch;
      _clientFrameCount++;
      if (now - _lastClientFrameTime >= 1000) {
        _clientFps = _clientFrameCount;
        _clientFrameCount = 0;
        _lastClientFrameTime = now;
      }

      // 2. Post frame to local Computer Vision Engine
      final requestPayload = jsonEncode({
        'image_base64': dataUrl,
        'timestamp': now / 1000.0,
      });

      final response = await html.HttpRequest.request(
        _cvEndpoint,
        method: 'POST',
        sendData: requestPayload,
        requestHeaders: {'Content-Type': 'application/json'},
      );

      if (response.status == 200 && mounted) {
        final data = jsonDecode(response.responseText ?? '{}') as Map<String, dynamic>;

        final isFaceDetected = data['face_detected'] as bool? ?? false;
        final faceConfidence = (data['face_confidence'] as num?)?.toDouble() ?? 0.0;
        final yaw = (data['yaw'] as num?)?.toDouble() ?? 0.0;
        final pitch = (data['pitch'] as num?)?.toDouble() ?? 0.0;
        final roll = (data['roll'] as num?)?.toDouble() ?? 0.0;
        final orientation = data['orientation'] as String? ?? 'UNKNOWN';
        final ear = (data['ear'] as num?)?.toDouble() ?? 0.0;
        final leftEar = (data['left_ear'] as num?)?.toDouble() ?? 0.0;
        final rightEar = (data['right_ear'] as num?)?.toDouble() ?? 0.0;
        final isDrowsy = data['is_drowsy'] as bool? ?? false;
        final phoneDetected = data['phone_detected'] as bool? ?? false;
        final phoneConfidence = (data['phone_confidence'] as num?)?.toDouble() ?? 0.0;
        final focusState = data['focus_state'] as String? ?? 'UNKNOWN';
        final engineFps = (data['fps'] as num?)?.toInt() ?? _clientFps;
        final latencyMs = (DateTime.now().millisecondsSinceEpoch - startTime).toDouble();

        // Parse Real Face Bounding Box
        double targetMinX = 0.25;
        double targetMinY = 0.20;
        double targetMaxX = 0.75;
        double targetMaxY = 0.76;

        if (isFaceDetected && data['bounding_box'] != null) {
          final bb = data['bounding_box'] as Map<String, dynamic>;
          targetMinX = (bb['x'] as num).toDouble().clamp(0.02, 0.90);
          targetMinY = (bb['y'] as num).toDouble().clamp(0.02, 0.90);
          final w = (bb['width'] as num).toDouble();
          final h = (bb['height'] as num).toDouble();
          targetMaxX = (targetMinX + w).clamp(targetMinX + 0.05, 0.98);
          targetMaxY = (targetMinY + h).clamp(targetMinY + 0.05, 0.98);
        }

        // Adjust for mirrored video display alignment
        if (widget.isMirrored) {
          final tempMin = 1.0 - targetMaxX;
          final tempMax = 1.0 - targetMinX;
          targetMinX = tempMin;
          targetMaxX = tempMax;
        }

        // EMA temporal smoothing for box rendering
        const alpha = 0.40;
        _smoothMinX = _smoothMinX * (1 - alpha) + targetMinX * alpha;
        _smoothMinY = _smoothMinY * (1 - alpha) + targetMinY * alpha;
        _smoothMaxX = _smoothMaxX * (1 - alpha) + targetMaxX * alpha;
        _smoothMaxY = _smoothMaxY * (1 - alpha) + targetMaxY * alpha;

        // Parse Real Landmark Anchor Points
        final rawLms = data['landmarks'] as List<dynamic>? ?? [];
        final List<Offset> landmarks = [];
        for (final raw in rawLms) {
          if (raw is List && raw.length >= 2) {
            double lx = (raw[0] as num).toDouble();
            double ly = (raw[1] as num).toDouble();
            if (widget.isMirrored) {
              lx = 1.0 - lx;
            }
            landmarks.add(Offset(lx, ly));
          }
        }

        // Human readable status message
        String statusMsg;
        if (phoneDetected) {
          statusMsg = 'PHONE DETECTED (${(phoneConfidence * 100).toInt()}%)';
        } else if (isDrowsy) {
          statusMsg = 'DROWSINESS (EYES CLOSED - EAR ${ear.toStringAsFixed(2)})';
        } else if (orientation == 'LOOKING_DOWN') {
          statusMsg = 'LOOKING DOWN (PITCH +${pitch.toInt()}°)';
        } else if (orientation == 'LOOKING_AWAY') {
          statusMsg = 'LOOKING AWAY (YAW ${yaw > 0 ? '+' : ''}${yaw.toInt()}°)';
        } else if (isFaceDetected) {
          statusMsg = 'FOCUSED ON MATERIAL';
        } else {
          statusMsg = 'AWAY FROM STUDY VIEW';
        }

        final phoneAvailable = data['phone_available'] as bool? ?? false;
        final attentionScore = focusState == 'FOCUSED' ? 0.95 : (isFaceDetected ? 0.35 : 0.0);

        final telemetry = RealTimeCvTelemetry(
          isFaceDetected: isFaceDetected,
          confidence: faceConfidence,
          box: Rect.fromLTRB(_smoothMinX, _smoothMinY, _smoothMaxX, _smoothMaxY),
          landmarks: landmarks,
          yaw: yaw,
          pitch: pitch,
          roll: roll,
          attentionScore: attentionScore,
          ear: ear,
          leftEar: leftEar,
          rightEar: rightEar,
          phoneDetected: phoneDetected,
          phoneConfidence: phoneConfidence,
          phoneAvailable: phoneAvailable,
          orientation: orientation,
          focusState: focusState,
          fps: engineFps > 0 ? engineFps : _clientFps,
          latencyMs: latencyMs,
          statusMessage: statusMsg,
        );

        widget.onTelemetry?.call(telemetry);
      } else if (mounted) {
        widget.onTelemetry?.call(
          RealTimeCvTelemetry(
            isFaceDetected: false,
            confidence: 0.0,
            box: const Rect.fromLTWH(0.25, 0.20, 0.50, 0.55),
            landmarks: const [],
            yaw: 0.0,
            pitch: 0.0,
            roll: 0.0,
            attentionScore: 0.0,
            ear: 0.0,
            leftEar: 0.0,
            rightEar: 0.0,
            phoneDetected: false,
            phoneConfidence: 0.0,
            phoneAvailable: false,
            orientation: 'UNKNOWN',
            focusState: 'CV_UNAVAILABLE',
            fps: 0,
            latencyMs: 0.0,
            statusMessage: 'CV ENGINE UNAVAILABLE (${response.status})',
          ),
        );
      }
    } catch (_) {
      // Non-fatal frame transmission failure
    } finally {
      _isProcessingFrame = false;
    }
  }

  @override
  void didUpdateWidget(covariant _WebCameraPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_videoElement != null && oldWidget.isMirrored != widget.isMirrored) {
      _videoElement!.style.transform = widget.isMirrored ? 'scaleX(-1)' : 'none';
    }
  }

  @override
  void dispose() {
    _cvProcessingTimer?.cancel();
    try {
      final stream = _videoElement?.srcObject as html.MediaStream?;
      stream?.getTracks().forEach((track) => track.stop());
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRegistered) return const SizedBox.shrink();
    return HtmlElementView(viewType: _elementId);
  }
}
