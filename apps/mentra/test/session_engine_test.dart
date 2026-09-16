import 'package:flutter_test/flutter_test.dart';
import 'package:mentra/features/study_session/domain/models/session_config.dart';
import 'package:mentra/features/study_session/domain/models/study_session_record.dart';
import 'package:mentra/features/study_session/domain/repositories/session_repository.dart';
import 'package:mentra/features/study_session/presentation/session_controller.dart';

class FakeSessionRepository implements SessionRepository {
  int saveCallsCount = 0;
  StudySessionRecord? lastSaved;

  @override
  Future<StudySessionRecord> saveSession(StudySessionRecord session) async {
    saveCallsCount++;
    lastSaved = session;
    return session;
  }

  @override
  Future<List<StudySessionRecord>> getRecentSessions({int limit = 10}) async {
    return lastSaved != null ? [lastSaved!] : [];
  }

  @override
  Future<Map<String, dynamic>> getSessionStatistics() async {
    return {'totalMinutes': 45};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionController State Machine', () {
    late SessionController controller;
    late FakeSessionRepository fakeRepo;
    const testConfig = SessionConfig(
      subjectId: 'sub_123',
      subjectTitle: 'Data Analytics',
      topicId: 'top_456',
      topicTitle: 'Regression Analysis',
      targetDurationMinutes: 45,
    );

    setUp(() {
      fakeRepo = FakeSessionRepository();
      controller = SessionController(sessionRepository: fakeRepo);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial state is idle', () {
      expect(controller.state, SessionState.idle);
      expect(controller.elapsedSeconds, 0);
      expect(controller.distractionsCount, 0);
    });

    test('setupSession transitions idle -> preparing', () {
      final success = controller.setupSession(testConfig);
      expect(success, isTrue);
      expect(controller.state, SessionState.preparing);
      expect(controller.currentConfig?.subjectTitle, 'Data Analytics');
      expect(controller.targetSeconds, 45 * 60);
    });

    test('startActiveSession fails if not preparing', () {
      expect(controller.startActiveSession(), isFalse);
      expect(controller.state, SessionState.idle);
    });

    test('Valid lifecycle: idle -> preparing -> active -> paused -> active -> completed -> idle', () async {
      // 1. Setup
      expect(controller.setupSession(testConfig), isTrue);
      expect(controller.state, SessionState.preparing);

      // 2. Start
      expect(controller.startActiveSession(), isTrue);
      expect(controller.state, SessionState.active);
      expect(controller.sessionStartTime, isNotNull);

      // 3. Pause
      expect(controller.pauseSession(), isTrue);
      expect(controller.state, SessionState.paused);
      expect(controller.pauseSession(), isFalse); // Double pause rejected

      // 4. Resume
      expect(controller.resumeSession(), isTrue);
      expect(controller.state, SessionState.active);
      expect(controller.resumeSession(), isFalse); // Double resume rejected

      // 5. End
      expect(controller.endSession(), isTrue);
      expect(controller.state, SessionState.completed);
      expect(controller.startActiveSession(), isFalse); // Cannot start directly from completed

      // 6. Save
      controller.setReflection(SessionReflection.excellent);
      final saved = await controller.saveCompletedSession();

      expect(saved, isNotNull);
      expect(saved?.subjectTitle, 'Data Analytics');
      expect(saved?.topicTitle, 'Regression Analysis');
      expect(saved?.reflection, SessionReflection.excellent);
      expect(fakeRepo.saveCallsCount, 1);
      expect(controller.state, SessionState.idle);
    });

    test('cancelSession returns to idle from any active stage', () {
      controller.setupSession(testConfig);
      controller.startActiveSession();
      expect(controller.state, SessionState.active);

      controller.cancelSession();
      expect(controller.state, SessionState.idle);
      expect(controller.currentConfig, isNull);
    });

    test('Idempotent saveCompletedSession prevents duplicate backend writes', () async {
      controller.setupSession(testConfig);
      controller.startActiveSession();
      controller.endSession();

      // Trigger concurrent saves
      final future1 = controller.saveCompletedSession();
      final future2 = controller.saveCompletedSession();

      await Future.wait([future1, future2]);

      expect(fakeRepo.saveCallsCount, 1);
    });

    test('Distraction telemetry updates focus score correctly', () {
      controller.setupSession(testConfig);
      controller.startActiveSession();

      controller.recordDistraction();
      controller.recordDistraction();
      expect(controller.distractionsCount, 2);

      controller.endSession();
      expect(controller.focusScore, (92 - (2 * 3))); // 86
    });

    test('Time formatting displays standard zero-padded strings', () {
      controller.setupSession(testConfig);
      expect(controller.formattedRemainingTime, '45:00');
      expect(controller.formattedElapsedTime, '00:00');
    });
  });
}
