import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentra/core/theme/app_theme.dart';
import 'package:mentra/features/ai_coach/data/repositories/mock_ai_coach_repository.dart';
import 'package:mentra/features/ai_coach/presentation/ai_coach_page.dart';
import 'package:mentra/features/study_session/domain/models/session_config.dart';
import 'package:mentra/features/study_session/presentation/session_controller.dart';
import 'package:mentra/features/study_session/presentation/session_summary_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M6 AI Coach — Repository Tests', () {
    late MockAiCoachRepository repository;

    setUp(() {
      repository = MockAiCoachRepository();
    });

    test('getCoachInsights returns structured behavioral insights', () async {
      final insights = await repository.getCoachInsights();
      expect(insights.length, greaterThanOrEqualTo(3));
      expect(insights.first.title, 'Optimal Focus Block Duration');
      expect(insights.first.impactMetric, contains('retention'));
    });

    test('getInitialChatHistory returns coach welcome message', () async {
      final history = await repository.getInitialChatHistory();
      expect(history.length, 1);
      expect(history.first.sender, 'coach');
      expect(history.first.text, contains('Mentra'));
    });

    test('askCoachQuestion generates contextual reply', () async {
      final reply = await repository.askCoachQuestion('How should I schedule my focus?');
      expect(reply.sender, 'coach');
      expect(reply.text, contains('attention curve'));
    });

    test('explainConcept produces structured breakdown', () async {
      final explanation = await repository.explainConcept('Neural Networks');
      expect(explanation['concept_name'], 'Neural Networks');
      expect(explanation['key_points'], isNotEmpty);
      expect(explanation['analogy'], isNotNull);
    });

    test('evaluateIntervention produces timely coaching recommendation', () async {
      final intervention = await repository.evaluateIntervention(
        subjectTitle: 'Machine Learning',
        topicTitle: 'Backpropagation',
        elapsedMinutes: 30,
        distractionsCount: 2,
        triggerReason: 'repeated_distraction',
      );
      expect(intervention['should_intervene'], isTrue);
      expect(intervention['intervention_message'], contains('30 minutes'));
    });

    test('analyzeSession provides post-session feedback', () async {
      final analysis = await repository.analyzeSession(
        sessionId: 'sess_999',
        subjectTitle: 'Physics',
        topicTitle: 'Electromagnetism',
        actualDurationMinutes: 45,
        targetDurationMinutes: 45,
        focusScore: 92,
        distractionsCount: 1,
        reflection: 'good',
      );
      expect(analysis['session_id'], 'sess_999');
      expect(analysis['focus_rating'], 'Strong');
      expect(analysis['what_went_well'], isNotEmpty);
    });
  });

  group('M6 AI Coach — Widget UI Tests', () {
    testWidgets('AiCoachPage renders greeting, insights, and chat workspace', (tester) async {
      final repo = MockAiCoachRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiCoachPage(aiCoachRepository: repo),
            ),
          ),
        ),
      );

      // Initial loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      // Header & Branding
      expect(find.text('MENTRA'), findsWidgets);
      expect(find.text('Your personal AI study coach'), findsOneWidget);
      expect(find.text('New Chat'), findsOneWidget);

      // Empty State & Starter Action Prompts
      expect(find.text('Learn something today.'), findsOneWidget);
      expect(find.text('Ask Mentra anything about your studies.'), findsOneWidget);
      expect(find.text('Explain a topic'), findsOneWidget);
      expect(find.text('Quiz me'), findsOneWidget);
      expect(find.text('Help me understand'), findsOneWidget);
      expect(find.text('Practice'), findsOneWidget);
    });

    testWidgets('SessionSummaryPage displays AI Coach Reflection analysis', (tester) async {
      final repo = MockAiCoachRepository();
      final controller = SessionController();

      controller.setupSession(const SessionConfig(
        subjectId: 'subj_1',
        subjectTitle: 'Data Analytics',
        topicId: 'top_1',
        topicTitle: 'Regression',
        targetDurationMinutes: 45,
      ));
      controller.startActiveSession();
      controller.endSession();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SessionSummaryPage(
            sessionController: controller,
            aiCoachRepository: repo,
            onDone: () {},
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Verify AI Coach Reflection section
      expect(find.text('AI Coach Reflection'), findsOneWidget);
      expect(find.textContaining('Strong focus throughout'), findsOneWidget);

      controller.dispose();
    });
  });
}
