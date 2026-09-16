import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mentra/core/network/api_client.dart';
import 'package:mentra/features/ai_coach/data/repositories/mock_ai_coach_repository.dart';
import 'package:mentra/features/analytics/data/repositories/mock_analytics_repository.dart';
import 'package:mentra/features/auth/services/auth_service.dart';
import 'package:mentra/features/auth/services/token_storage_service.dart';
import 'package:mentra/features/goals/data/repositories/mock_goal_repository.dart';
import 'package:mentra/features/notes/data/repositories/mock_note_repository.dart';
import 'package:mentra/features/study_session/data/repositories/mock_session_repository.dart';
import 'package:mentra/features/subjects/data/repositories/mock_subject_repository.dart';
import 'package:mentra/main.dart';

void main() {
  testWidgets('Mentra app navigates full onboarding flow to Auth', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final storage = InMemoryTokenStorage();
    final authService = AuthService(tokenStorage: storage);

    await tester.pumpWidget(MentraRoot(
      authService: authService,
      initialShowOnboarding: true,
    ));
    await tester.pumpAndSettle();

    // Step 1: Welcome
    expect(find.text('WELCOME TO MENTRA'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Step 2
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('STRUCTURE & CLARITY'), findsOneWidget);

    // Step 3
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('LOCAL FOCUS MONITORING'), findsOneWidget);

    // Step 4
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('PERSONALIZED COACHING'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Complete Onboarding -> Auth
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('MENTRA'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
  });

  testWidgets('Mentra app transitions to WorkspaceLayout on successful login and navigates all workspace features', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'access_token': 'fake_jwt_token',
            'token_type': 'bearer',
            'user': {
              'id': 'usr_test_123',
              'email': 'student@mentra.ai',
              'full_name': 'Alex Student',
              'is_active': true,
              'created_at': '2026-08-31T20:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/v1/users/me') {
        return http.Response(
          jsonEncode({
            'id': 'usr_test_123',
            'email': 'student@mentra.ai',
            'full_name': 'Alex Student',
            'is_active': true,
            'created_at': '2026-08-31T20:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not Found', 404);
    });

    final storage = InMemoryTokenStorage();
    final authService = AuthService(
      apiClient: ApiClient(httpClient: mockClient),
      tokenStorage: storage,
    );

    await tester.pumpWidget(MentraRoot(
      authService: authService,
      subjectRepository: MockSubjectRepository(),
      noteRepository: MockNoteRepository(),
      goalRepository: MockGoalRepository(),
      sessionRepository: MockSessionRepository(),
      analyticsRepository: MockAnalyticsRepository(),
      aiCoachRepository: MockAiCoachRepository(),
    ));
    await tester.pumpAndSettle();

    // Fill credentials & Log in
    await tester.enterText(find.widgetWithText(TextFormField, 'you@example.com'), 'student@mentra.ai');
    await tester.enterText(find.widgetWithText(TextFormField, '••••••••'), 'Password123!');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(GestureDetector, 'Sign In').first);
    await tester.pumpAndSettle();

    // Verify Home Page
    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Start Study Session'), findsWidgets);

    // 1. Navigate to Subjects
    await tester.tap(find.text('Subjects'));
    await tester.pumpAndSettle();
    expect(find.text('Data Analytics'), findsOneWidget);
    expect(find.text('Software Engineering'), findsOneWidget);

    // Open Subject Workspace
    await tester.tap(find.widgetWithText(GestureDetector, 'Open Workspace').first);
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Topics'), findsOneWidget);

    // Open Topic View
    await tester.tap(find.widgetWithText(GestureDetector, 'View Topic').first);
    await tester.pumpAndSettle();
    expect(find.text('Key Concepts & Checkpoints'), findsOneWidget);

    // Go back to Subjects
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // 2. Navigate to Notes
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('Capture lecture notes, formulas, and structured summaries'), findsOneWidget);
    expect(find.text('Open Note'), findsWidgets);

    // Open Note Editor
    await tester.tap(find.widgetWithText(GestureDetector, 'Open Note').first);
    await tester.pumpAndSettle();
    expect(find.text('Save Note'), findsOneWidget);

    // Back to Notes list
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // 3. Navigate to Goals
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    expect(find.text('What are you working toward?'), findsNothing); // Uses subtitle
    expect(find.text('Track learning milestones, exam preparation, and study targets'), findsOneWidget);

    // 4. Navigate to Analytics
    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle();
    expect(find.text('Daily Focus & Attention Trend'), findsOneWidget);
    expect(find.text('Distraction Telemetry Breakdown'), findsOneWidget);

    // 5. Navigate to AI Coach
    await tester.tap(find.text('AI Coach'));
    await tester.pumpAndSettle();
    expect(find.text('Study Coach Active'), findsOneWidget);
    expect(find.text('Ask Mentra'), findsOneWidget);

    // 6. Navigate to Settings & Test Theme Switch
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Student'), findsOneWidget);

    // Switch to Appearance Tab
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    // Switch to Dark Theme
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    // Switch to Light Theme
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
  });

  testWidgets('Mentra app completes full 5-stage study session lifecycle', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final storage = InMemoryTokenStorage();
    await storage.saveToken('valid_stored_token');

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'id': 'usr_saved_456',
          'email': 'scholar@mentra.ai',
          'full_name': 'Scholar Mentra',
          'is_active': true,
          'created_at': '2026-08-31T20:00:00Z',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final authService = AuthService(
      apiClient: ApiClient(httpClient: mockClient),
      tokenStorage: storage,
    );

    await tester.pumpWidget(MentraRoot(
      authService: authService,
      subjectRepository: MockSubjectRepository(),
      noteRepository: MockNoteRepository(),
      goalRepository: MockGoalRepository(),
      sessionRepository: MockSessionRepository(),
      analyticsRepository: MockAnalyticsRepository(),
      aiCoachRepository: MockAiCoachRepository(),
    ));
    await tester.pumpAndSettle();

    // 1. Launch Setup Dialog from Home
    await tester.tap(find.widgetWithText(GestureDetector, 'Start Study Session').first);
    await tester.pumpAndSettle();
    expect(find.text('Start a study session'), findsOneWidget);

    // Tap Begin Session -> Takes to Stage 2: Preparation
    await tester.tap(find.widgetWithText(GestureDetector, 'Begin Session'));
    await tester.pumpAndSettle();
    expect(find.text("You're ready."), findsOneWidget);
    expect(find.text('Local Camera Permission'), findsOneWidget);

    // 2. Start Active Session -> Stage 3: Active Study
    await tester.tap(find.widgetWithText(GestureDetector, 'Start Session'));
    await tester.pumpAndSettle();
    expect(find.text('MENTRA FOCUS'), findsOneWidget);
    expect(find.text('LIVE SESSION'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);

    // 3. Pause & Resume Session -> Stage 4: Pause
    await tester.tap(find.widgetWithText(GestureDetector, 'Pause'));
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume Focus'), findsOneWidget);

    await tester.tap(find.widgetWithText(GestureDetector, 'Resume Focus'));
    await tester.pumpAndSettle();
    expect(find.text('Focused'), findsOneWidget);

    // 4. End Session -> Stage 5: Summary
    await tester.tap(find.widgetWithText(GestureDetector, 'End Session'));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('End Study Session?'), findsOneWidget);
    await tester.tap(find.widgetWithText(GestureDetector, 'End Session').last);
    await tester.pumpAndSettle();

    // Stage 5: Session Summary & Reflection
    expect(find.text('Great work, focus achieved.'), findsOneWidget);
    expect(find.text('Session Reflection'), findsOneWidget);

    // Select 'Excellent' reflection
    await tester.tap(find.text('Excellent'));
    await tester.pumpAndSettle();

    // Save & Return
    await tester.tap(find.widgetWithText(GestureDetector, 'Save & Return to Workspace'));
    await tester.pumpAndSettle();

    // Verify returned to Home
    expect(find.text('Good morning'), findsOneWidget);
  });
}
