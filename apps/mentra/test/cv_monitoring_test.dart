import 'package:flutter_test/flutter_test.dart';
import 'package:mentra/features/cv_monitoring/domain/detectors/distraction_detector.dart';
import 'package:mentra/features/cv_monitoring/domain/detectors/drowsiness_detector.dart';
import 'package:mentra/features/cv_monitoring/domain/detectors/face_presence_detector.dart';
import 'package:mentra/features/cv_monitoring/domain/engine/focus_event_engine.dart';
import 'package:mentra/features/cv_monitoring/domain/models/monitoring_models.dart';
import 'package:mentra/features/cv_monitoring/domain/services/focus_monitoring_service.dart';
import 'package:mentra/features/study_session/domain/models/session_config.dart';
import 'package:mentra/features/study_session/presentation/session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M5 Computer Vision — FacePresenceDetector Tests', () {
    late FacePresenceDetector detector;
    final config = const MonitoringConfig(
      faceAbsentThresholdSeconds: 3.0,
      minConfidenceThreshold: 0.60,
    );

    setUp(() {
      detector = FacePresenceDetector(config: config);
    });

    test('Single dropped frame does not trigger faceAbsent event (debouncing)', () {
      final t0 = DateTime(2026, 9, 16, 10, 0, 0);

      // Frame 1: Normal face
      final evt1 = detector.processObservation(FocusObservation.focused(t0));
      expect(evt1, isNull);
      expect(detector.isAway, isFalse);

      // Frame 2: Transient glitch (0.3s later)
      final evt2 = detector.processObservation(
        FocusObservation.away(t0.add(const Duration(milliseconds: 300))),
      );
      expect(evt2, isNull);
      expect(detector.isAway, isFalse);

      // Frame 3: Normal face recovers (0.6s later)
      final evt3 = detector.processObservation(
        FocusObservation.focused(t0.add(const Duration(milliseconds: 600))),
      );
      expect(evt3, isNull);
      expect(detector.isAway, isFalse);
    });

    test('Sustained absence beyond threshold triggers faceAbsent event', () {
      final t0 = DateTime(2026, 9, 16, 10, 0, 0);

      detector.processObservation(FocusObservation.away(t0));
      detector.processObservation(FocusObservation.away(t0.add(const Duration(seconds: 1))));
      detector.processObservation(FocusObservation.away(t0.add(const Duration(seconds: 2))));

      // 3.5s later -> exceeds 3.0s threshold
      final evtAway = detector.processObservation(
        FocusObservation.away(t0.add(const Duration(milliseconds: 3500))),
      );

      expect(evtAway, isNotNull);
      expect(evtAway!.type, FocusEventType.faceAbsent);
      expect(detector.isAway, isTrue);

      // Subsequent away frame does not duplicate the event
      final evtDup = detector.processObservation(
        FocusObservation.away(t0.add(const Duration(seconds: 4))),
      );
      expect(evtDup, isNull);

      // Returning to view emits focusPresent
      final evtReturn = detector.processObservation(
        FocusObservation.focused(t0.add(const Duration(seconds: 5))),
      );
      expect(evtReturn, isNotNull);
      expect(evtReturn!.type, FocusEventType.focusPresent);
      expect(detector.isAway, isFalse);
    });
  });

  group('M5 Computer Vision — DrowsinessDetector Tests', () {
    late DrowsinessDetector detector;
    final config = const MonitoringConfig(
      drowsinessDurationThresholdSeconds: 2.0,
      minConfidenceThreshold: 0.60,
    );

    setUp(() {
      detector = DrowsinessDetector(config: config);
    });

    test('Natural eye blinks (< 500ms) do NOT trigger drowsiness alert', () {
      final t0 = DateTime(2026, 9, 16, 10, 0, 0);

      // Normal open eyes
      expect(detector.processObservation(FocusObservation.focused(t0)), isNull);

      // Brief blink 200ms
      expect(
        detector.processObservation(
          FocusObservation.eyesClosed(t0.add(const Duration(milliseconds: 200))),
        ),
        isNull,
      );

      // Eyes open again at 400ms
      expect(
        detector.processObservation(
          FocusObservation.focused(t0.add(const Duration(milliseconds: 400))),
        ),
        isNull,
      );
      expect(detector.isDrowsy, isFalse);
    });

    test('Continuous closed eyes >= 2.0s triggers drowsiness alert', () {
      final t0 = DateTime(2026, 9, 16, 10, 0, 0);

      detector.processObservation(FocusObservation.eyesClosed(t0));
      detector.processObservation(
        FocusObservation.eyesClosed(t0.add(const Duration(milliseconds: 800))),
      );
      detector.processObservation(
        FocusObservation.eyesClosed(t0.add(const Duration(milliseconds: 1600))),
      );

      // At 2.2s -> threshold satisfied
      final evt = detector.processObservation(
        FocusObservation.eyesClosed(t0.add(const Duration(milliseconds: 2200))),
      );

      expect(evt, isNotNull);
      expect(evt!.type, FocusEventType.drowsinessDetected);
      expect(detector.isDrowsy, isTrue);

      // Opening eyes resets drowsiness
      final openEvt = detector.processObservation(
        FocusObservation.focused(t0.add(const Duration(milliseconds: 3000))),
      );
      expect(openEvt, isNull);
      expect(detector.isDrowsy, isFalse);
    });
  });

  group('M5 Computer Vision — DistractionDetector Tests', () {
    late DistractionDetector detector;
    final config = const MonitoringConfig(
      distractionDurationThresholdSeconds: 2.0,
      minConfidenceThreshold: 0.60,
    );

    setUp(() {
      detector = DistractionDetector(config: config);
    });

    test('Transient phone glimpse does not fire distraction alert', () {
      final t0 = DateTime(2026, 9, 16, 10, 0, 0);

      expect(
        detector.processObservation(FocusObservation.distracted(t0, 'phone')),
        isNull,
      );

      // Returned to focus at 500ms
      expect(
        detector.processObservation(
          FocusObservation.focused(t0.add(const Duration(milliseconds: 500))),
        ),
        isNull,
      );
      expect(detector.isDistracted, isFalse);
    });

    test('Continuous distraction >= 2.0s emits distractionDetected event', () {
      final t0 = DateTime(2026, 9, 16, 10, 0, 0);

      detector.processObservation(FocusObservation.distracted(t0, 'phone'));
      detector.processObservation(
        FocusObservation.distracted(t0.add(const Duration(seconds: 1)), 'phone'),
      );

      final evt = detector.processObservation(
        FocusObservation.distracted(t0.add(const Duration(milliseconds: 2100)), 'phone'),
      );

      expect(evt, isNotNull);
      expect(evt!.type, FocusEventType.distractionDetected);
      expect(detector.isDistracted, isTrue);
    });
  });

  group('M5 FocusEventEngine & Cooldown Tests', () {
    late FocusEventEngine engine;
    final config = const MonitoringConfig(
      drowsinessDurationThresholdSeconds: 1.0,
      distractionDurationThresholdSeconds: 1.0,
      faceAbsentThresholdSeconds: 1.5,
      alertCooldownSeconds: 15.0,
    );

    setUp(() {
      engine = FocusEventEngine(config: config);
    });

    tearDown(() {
      engine.dispose();
    });

    test('Alert cooldown suppresses repetitive spam alerts within cooldown window', () {
      final t0 = DateTime(2026, 9, 16, 10, 0, 0);

      // Trigger first drowsiness alert at t0 + 1.2s
      engine.ingestObservation(FocusObservation.eyesClosed(t0));
      engine.ingestObservation(
        FocusObservation.eyesClosed(t0.add(const Duration(milliseconds: 500))),
      );
      final events1 = engine.ingestObservation(
        FocusObservation.eyesClosed(t0.add(const Duration(milliseconds: 1200))),
      );

      expect(events1.length, 1);
      expect(events1.first.type, FocusEventType.drowsinessDetected);
      expect(engine.drowsinessEventCount, 1);

      // Reset eye state then trigger another closure at t0 + 5.0s (within 15s cooldown)
      engine.ingestObservation(
        FocusObservation.focused(t0.add(const Duration(seconds: 3))),
      );
      engine.ingestObservation(
        FocusObservation.eyesClosed(t0.add(const Duration(seconds: 4))),
      );
      engine.ingestObservation(
        FocusObservation.eyesClosed(t0.add(const Duration(milliseconds: 4500))),
      );
      final eventsSuppressed = engine.ingestObservation(
        FocusObservation.eyesClosed(t0.add(const Duration(milliseconds: 5200))),
      );

      // Suppressed due to active 15s cooldown
      expect(eventsSuppressed, isEmpty);
      expect(engine.drowsinessEventCount, 1);

      // Trigger after 16s cooldown passes -> allowed
      engine.ingestObservation(
        FocusObservation.focused(t0.add(const Duration(seconds: 16))),
      );
      engine.ingestObservation(
        FocusObservation.eyesClosed(t0.add(const Duration(seconds: 17))),
      );
      engine.ingestObservation(
        FocusObservation.eyesClosed(t0.add(const Duration(milliseconds: 17500))),
      );
      final eventsAllowed = engine.ingestObservation(
        FocusObservation.eyesClosed(t0.add(const Duration(milliseconds: 18200))),
      );

      expect(eventsAllowed.length, 1);
      expect(engine.drowsinessEventCount, 2);
    });
  });

  group('M5 SessionController Integration Tests', () {
    test('Session automatically starts and pauses CV service with session state', () async {
      final mockCv = SyntheticFocusMonitoringService(initialStatus: MonitoringStatus.ready);
      final controller = SessionController(focusMonitoringService: mockCv);

      final config = const SessionConfig(
        subjectId: 'subj_1',
        subjectTitle: 'Machine Learning',
        topicId: 'top_1',
        topicTitle: 'Neural Networks',
        targetDurationMinutes: 25,
      );

      // 1. Setup session
      controller.setupSession(config);
      expect(controller.state, SessionState.preparing);
      expect(mockCv.status, MonitoringStatus.ready);

      // 2. Start active session -> CV monitoring transitions to running
      controller.startActiveSession();
      expect(controller.state, SessionState.active);
      expect(mockCv.status, MonitoringStatus.running);

      // 3. Pause session -> CV monitoring pauses
      controller.pauseSession();
      expect(controller.state, SessionState.paused);
      expect(mockCv.status, MonitoringStatus.paused);

      // 4. Resume session -> CV monitoring resumes
      controller.resumeSession();
      expect(controller.state, SessionState.active);
      expect(mockCv.status, MonitoringStatus.running);

      // 5. Complete session -> CV monitoring stops
      controller.endSession();
      expect(controller.state, SessionState.completed);
      expect(mockCv.status, MonitoringStatus.stopped);

      controller.dispose();
    });

    test('CV events automatically increment distractions and update focus score', () async {
      final mockCv = SyntheticFocusMonitoringService(initialStatus: MonitoringStatus.ready);
      final controller = SessionController(focusMonitoringService: mockCv);

      controller.setupSession(const SessionConfig(
        subjectId: 'subj_1',
        subjectTitle: 'Physics',
        topicId: 'top_1',
        topicTitle: 'Thermodynamics',
        targetDurationMinutes: 15,
      ));
      controller.startActiveSession();
      expect(controller.distractionsCount, 0);

      // Emit a distraction event
      mockCv.emitObservation(FocusObservation.distracted(DateTime.now(), 'phone'));
      mockCv.emitObservation(
        FocusObservation.distracted(DateTime.now().add(const Duration(seconds: 3)), 'phone'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.distractionsCount, 1);
      expect(controller.latestAlertEvent?.type, FocusEventType.distractionDetected);

      // Dismiss alert
      controller.dismissLatestAlert();
      expect(controller.latestAlertEvent, isNull);

      controller.endSession();
      controller.dispose();
    });

    test('Session functions smoothly without crashing when camera permission is denied', () async {
      final mockCv = SyntheticFocusMonitoringService(
        initialStatus: MonitoringStatus.permissionDenied,
      );
      final controller = SessionController(focusMonitoringService: mockCv);

      controller.setupSession(const SessionConfig(
        subjectId: 'subj_1',
        subjectTitle: 'Chemistry',
        topicId: 'top_1',
        topicTitle: 'Organic Synthesis',
        targetDurationMinutes: 10,
      ));
      expect(controller.monitoringStatus, MonitoringStatus.permissionDenied);

      // Session start works gracefully in timer mode
      expect(controller.startActiveSession(), isTrue);
      expect(controller.state, SessionState.active);

      // Pause and resume work cleanly
      expect(controller.pauseSession(), isTrue);
      expect(controller.resumeSession(), isTrue);
      expect(controller.endSession(), isTrue);

      controller.dispose();
    });
  });
}
