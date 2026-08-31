import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mentra/core/network/api_client.dart';
import 'package:mentra/features/auth/services/auth_service.dart';
import 'package:mentra/features/auth/services/token_storage_service.dart';
import 'package:mentra/main.dart';

void main() {
  testWidgets('Mentra app shows AuthView when unauthenticated', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final emptyStorage = InMemoryTokenStorage();
    final authService = AuthService(
      tokenStorage: emptyStorage,
    );

    await tester.pumpWidget(MentraRoot(authService: authService));
    await tester.pumpAndSettle();

    // Verify Auth view is displayed
    expect(find.text('MENTRA'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Toggle to Create Account via text containing Create Account
    await tester.tap(find.textContaining("Don't have an account?"));
    await tester.pumpAndSettle();
    expect(find.text('Full Name'), findsOneWidget);
  });

  testWidgets('Mentra app transitions to WorkspaceLayout on successful login and logs out', (WidgetTester tester) async {
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

    await tester.pumpWidget(MentraRoot(authService: authService));
    await tester.pumpAndSettle();

    // Fill in credentials
    await tester.enterText(find.widgetWithText(TextFormField, 'you@example.com'), 'student@mentra.ai');
    await tester.enterText(find.widgetWithText(TextFormField, '••••••••'), 'Password123!');
    await tester.pumpAndSettle();

    // Tap Sign In button
    await tester.tap(find.widgetWithText(GestureDetector, 'Sign In').first);
    await tester.pumpAndSettle();

    // Verify workspace layout is now active
    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Ready to focus?'), findsOneWidget);
    expect(find.text('Start Study Session'), findsOneWidget);
    expect(find.text('Subjects'), findsOneWidget);

    // Navigate to Settings
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Student'), findsOneWidget);
    expect(find.text('student@mentra.ai • Active Session'), findsOneWidget);

    // Tap Log Out button
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Log out of Mentra?'), findsOneWidget);
    await tester.tap(find.widgetWithText(GestureDetector, 'Log Out').last);
    await tester.pumpAndSettle();

    // Verify return to AuthView
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Email Address'), findsOneWidget);
  });

  testWidgets('Mentra app automatically restores authenticated session on launch', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/v1/users/me') {
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
      }
      return http.Response('Not Found', 404);
    });

    final storage = InMemoryTokenStorage();
    await storage.saveToken('valid_stored_token');

    final authService = AuthService(
      apiClient: ApiClient(httpClient: mockClient),
      tokenStorage: storage,
    );

    await tester.pumpWidget(MentraRoot(authService: authService));
    await tester.pumpAndSettle();

    // Verify workspace opens directly
    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Today\'s Progress'), findsOneWidget);
  });
}
