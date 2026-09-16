// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, unnecessary_cast
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Web implementation of live camera feed using HTML5 VideoElement & getUserMedia
Widget buildPlatformCameraView({required String viewId, required bool isMirrored}) {
  return _WebCameraPlayer(viewId: viewId, isMirrored: isMirrored);
}

class _WebCameraPlayer extends StatefulWidget {
  const _WebCameraPlayer({required this.viewId, required this.isMirrored});
  final String viewId;
  final bool isMirrored;

  @override
  State<_WebCameraPlayer> createState() => _WebCameraPlayerState();
}

class _WebCameraPlayerState extends State<_WebCameraPlayer> {
  html.VideoElement? _videoElement;
  bool _isRegistered = false;
  late final String _elementId;

  @override
  void initState() {
    super.initState();
    _elementId = 'mentra-webcam-${widget.viewId}-${DateTime.now().millisecondsSinceEpoch}';
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

    // Request camera access
    html.window.navigator.mediaDevices?.getUserMedia({'video': true}).then((stream) {
      if (mounted && _videoElement != null) {
        _videoElement!.srcObject = stream;
        _videoElement!.play();
      }
    }).catchError((_) {
      // Gracefully handle denied permission or headless test
    });
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
