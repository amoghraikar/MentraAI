import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentra/features/cv_monitoring/domain/models/monitoring_models.dart';
import 'package:mentra/features/cv_monitoring/domain/services/focus_monitoring_service.dart';
import 'package:mentra/features/study_session/domain/models/session_config.dart';
import 'package:mentra/features/study_session/presentation/session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 6 — CV Calibration & Baseline Models', () {
    test('CVBaseline serializes and deserializes accurately without identity data', () {
      final json = {
        'face_center_x': 0.52,
        'face_center_y': 0.48,
        'face_size': 0.125,
        'baseline_yaw': 3.2,
        'baseline_pitch': -2.1,
        'baseline_roll': 0.5,
        'normal_ear': 0.31,
        'calibration_duration': 3.0,
        'sample_count': 25,
        'quality': 'GOOD',
        'created_at': 1700000000.0,
      };

      final baseline = CVBaseline.fromJson(json);
      expect(baseline.faceCenterX, 0.52);
      expect(baseline.baselineYaw, 3.2);
      expect(baseline.baselinePitch, -2.1);
      expect(baseline.normalEar, 0.31);
      expect(baseline.quality, 'GOOD');

      final serialized = baseline.toJson();
      expect(serialized['face_size'], 0.125);
      expect(serialized['normal_ear'], 0.31);
    });

    test('CameraQualityInfo accurately classifies conditions and feedback', () {
      final qualityGood = CameraQualityInfo.fromJson({
        'status': 'GOOD',
        'face_visible': true,
        'face_size_ratio': 0.11,
        'brightness': 125.0,
        'landmark_quality': 1.0,
        'user_message': 'Optimal camera conditions.',
      });

      expect(qualityGood.status, 'GOOD');
      expect(qualityGood.faceVisible, true);

      final qualityPoor = CameraQualityInfo.fromJson({
        'status': 'POOR',
        'face_visible': false,
        'face_size_ratio': 0.0,
        'brightness': 20.0,
        'landmark_quality': 0.0,
        'user_message': 'Room is too dark. Increase lighting.',
      });

      expect(qualityPoor.status, 'POOR');
      expect(qualityPoor.userMessage, contains('lighting'));
    });

    test('RealTimeCvTelemetry supports baseline deviations and duration breakdown', () {
      const telemetry = RealTimeCvTelemetry(
        isFaceDetected: true,
        confidence: 0.92,
        box: Rect.fromLTWH(0.2, 0.2, 0.5, 0.5),
        landmarks: [],
        yaw: 18.0,
        pitch: -2.0,
        roll: 1.0,
        yawDeviation: 15.0,
        pitchDeviation: 1.0,
        rollDeviation: 0.5,
        attentionScore: 0.70,
        ear: 0.29,
        leftEar: 0.29,
        rightEar: 0.29,
        phoneDetected: false,
        phoneConfidence: 0.0,
        phoneAvailable: true,
        orientation: 'LOOKING_AWAY',
        focusState: 'LOOKING_AWAY',
        confidenceLevel: 'HIGH_CONFIDENCE',
        cameraQuality: CameraQualityInfo(
          status: 'GOOD',
          faceVisible: true,
          faceSizeRatio: 0.12,
          brightness: 120.0,
          landmarkQuality: 1.0,
          userMessage: 'Optimal',
        ),
        fps: 25,
        latencyMs: 14.5,
        statusMessage: 'LOOKING AWAY',
        baselineActive: true,
        focusedDuration: 120.0,
        lookingAwayDuration: 15.0,
        eyesClosedDuration: 2.0,
        possibleDrowsinessDuration: 0.0,
        phoneDetectedDuration: 0.0,
        faceNotDetectedDuration: 5.0,
        unknownDuration: 3.0,
        distractionCount: 2,
        focusScore: 85,
      );

      expect(telemetry.yawDeviation, 15.0);
      expect(telemetry.baselineActive, true);
      expect(telemetry.focusedDuration, 120.0);
      expect(telemetry.focusScore, 85);
      expect(telemetry.unknownDuration, 3.0);
    });
  });

  group('Milestone 6 — Real Focus Session Metrics & Scoring Engine', () {
    late SessionController controller;
    late SyntheticFocusMonitoringService monitoringService;

    setUp(() {
      monitoringService = SyntheticFocusMonitoringService(
        initialStatus: MonitoringStatus.ready,
      );
      controller = SessionController(
        focusMonitoringService: monitoringService,
      );
      controller.setupSession(
        const SessionConfig(
          subjectId: 'sub_1',
          subjectTitle: 'Computer Vision',
          topicId: 'top_1',
          topicTitle: 'Calibration & Head Pose',
          targetDurationMinutes: 25,
          studyMode: 'Focus',
        ),
      );
      controller.startActiveSession();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Accumulates real durations and separates unknown time from focused time', () {
      final t0 = DateTime(2026, 9, 20, 10, 0, 0);

      // 1. Initial 4 seconds focused
      controller.recordCvObservation(
        FocusObservation(
          timestamp: t0,
          isFaceDetected: true,
          focusState: 'FOCUSED',
        ),
      );
      controller.recordCvObservation(
        FocusObservation(
          timestamp: t0.add(const Duration(seconds: 4)),
          isFaceDetected: true,
          focusState: 'FOCUSED',
        ),
      );

      expect(controller.focusedDuration, 4.0);
      expect(controller.focusScore, 100);

      // 2. 2 seconds of looking away
      controller.recordCvObservation(
        FocusObservation(
          timestamp: t0.add(const Duration(seconds: 6)),
          isFaceDetected: true,
          focusState: 'LOOKING_AWAY',
        ),
      );

      expect(controller.focusedDuration, 4.0);
      expect(controller.lookingAwayDuration, 2.0);

      // Score = 4 / (4 + 2) = 67%
      expect(controller.focusScore, 67);

      // 3. 2 seconds of UNKNOWN (e.g. camera glitch or mesh initializing)
      controller.recordCvObservation(
        FocusObservation(
          timestamp: t0.add(const Duration(seconds: 8)),
          isFaceDetected: false,
          focusState: 'UNKNOWN',
        ),
      );

      expect(controller.unknownDuration, 2.0);
      // UNKNOWN is strictly excluded from focused time! Score remains 67%
      expect(controller.focusedDuration, 4.0);
      expect(controller.focusScore, 67);
      expect(controller.totalObservedSeconds, 8.0);
    });

    test('Pausing study session freezes CV observation accumulation', () {
      final t0 = DateTime(2026, 9, 20, 10, 0, 0);

      // Tick 3 seconds focused
      controller.recordCvObservation(
        FocusObservation(timestamp: t0, isFaceDetected: true, focusState: 'FOCUSED'),
      );
      controller.recordCvObservation(
        FocusObservation(timestamp: t0.add(const Duration(seconds: 3)), isFaceDetected: true, focusState: 'FOCUSED'),
      );
      expect(controller.focusedDuration, 3.0);

      // Pause session
      controller.pauseSession();
      expect(controller.state, SessionState.paused);

      // Observations emitted during pause MUST NOT accumulate
      controller.recordCvObservation(
        FocusObservation(timestamp: t0.add(const Duration(seconds: 15)), isFaceDetected: true, focusState: 'FOCUSED'),
      );
      expect(controller.focusedDuration, 3.0);

      // Resume session
      controller.resumeSession();
      expect(controller.state, SessionState.active);

      // Now observation starts accumulating again cleanly
      controller.recordCvObservation(
        FocusObservation(timestamp: t0.add(const Duration(seconds: 20)), isFaceDetected: true, focusState: 'FOCUSED'),
      );
      controller.recordCvObservation(
        FocusObservation(timestamp: t0.add(const Duration(seconds: 22)), isFaceDetected: true, focusState: 'FOCUSED'),
      );
      expect(controller.focusedDuration, 5.0);
    });
  });
}
