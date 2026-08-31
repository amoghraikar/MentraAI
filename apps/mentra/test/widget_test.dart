import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentra/main.dart';

void main() {
  testWidgets('Mentra workspace shell initializes and displays Home view', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MentraRoot());
    await tester.pumpAndSettle();

    // Verify Mentra branding in sidebar
    expect(find.text('MENTRA'), findsOneWidget);
    expect(find.text('AI Study Coach'), findsOneWidget);

    // Verify all sidebar navigation labels exist
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Subjects'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('AI Coach'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify Home page specific content
    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Ready to focus?'), findsOneWidget);
    expect(find.text('Start Study Session'), findsOneWidget);
    expect(find.text("Today's Progress"), findsOneWidget);
    expect(find.text('Continue Studying'), findsOneWidget);
    expect(find.text('Mentra Insight'), findsOneWidget);
  });

  testWidgets('Mentra workspace shell navigates across all routes smoothly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MentraRoot());
    await tester.pumpAndSettle();

    // 1. Navigate to Subjects
    await tester.tap(find.text('Subjects'));
    await tester.pumpAndSettle();
    expect(find.text('Your study subjects and curriculum progress'), findsOneWidget);
    expect(find.text('Data Analytics'), findsWidgets);
    expect(find.text('Software Engineering'), findsWidgets);
    expect(find.text('Web Programming'), findsWidgets);

    // Tap a subject card to verify modal topic dialog
    await tester.tap(find.text('Data Analytics').first);
    await tester.pumpAndSettle();
    expect(find.text('Topics Covered:'), findsOneWidget);
    expect(find.text('Correlation & Regression'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // 2. Navigate to Notes & test search filter
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('Your study notes, session thoughts, and summaries'), findsOneWidget);
    expect(find.text('Correlation & Regression'), findsOneWidget);
    expect(find.text('HTML & CSS Architecture'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Regression');
    await tester.pumpAndSettle();
    expect(find.text('Correlation & Regression'), findsOneWidget);
    expect(find.text('HTML & CSS Architecture'), findsNothing);

    // 3. Navigate to Goals
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    expect(find.text('Your study goals, milestones, and target deadlines'), findsOneWidget);
    expect(find.text('Complete Data Analytics Unit II'), findsOneWidget);
    expect(find.text('Complete Software Engineering revision'), findsOneWidget);

    // 4. Navigate to Analytics
    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle();
    expect(find.text('Your learning performance, telemetry insights, and focus history'), findsOneWidget);
    expect(find.text('Focus Trend'), findsOneWidget);
    expect(find.text('Subject Distribution'), findsOneWidget);

    // 5. Navigate to AI Coach
    await tester.tap(find.text('AI Coach'));
    await tester.pumpAndSettle();
    expect(find.text('Personalized study insights, focus guidance, and learning patterns'), findsOneWidget);
    expect(find.text('Recent Insight'), findsOneWidget);
    expect(find.text('Focus Recommendations'), findsOneWidget);

    // 6. Navigate to Settings & test tabs and theme switching
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Manage your workspace, appearance, privacy, and study preferences'), findsOneWidget);
    expect(find.text('Profile Settings'), findsOneWidget);

    // Switch to Appearance tab
    await tester.tap(find.text('Appearance').first);
    await tester.pumpAndSettle();
    expect(find.text('Theme Mode'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    // Toggle Dark theme
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    // Switch to Privacy tab
    await tester.tap(find.text('Privacy').first);
    await tester.pumpAndSettle();
    expect(find.text('On-Device Privacy Guarantee'), findsOneWidget);
  });
}
