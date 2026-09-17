import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentra/core/theme/app_theme.dart';
import 'package:mentra/features/analytics/data/repositories/mock_analytics_repository.dart';
import 'package:mentra/features/analytics/domain/models/analytics_data.dart';
import 'package:mentra/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:mentra/features/analytics/presentation/analytics_page.dart';

class EmptyMockAnalyticsRepository implements AnalyticsRepository {
  @override
  Future<AnalyticsOverviewModel> getAnalyticsSummary({
    AnalyticsTimeRange timeRange = AnalyticsTimeRange.sevenDays,
  }) async {
    return AnalyticsOverviewModel(
      timeRange: timeRange.apiValue,
      totalStudyMinutes: 0,
      totalStudyTimeFormatted: '0h 0m',
      totalSessionsCount: 0,
      completedSessionsCount: 0,
      averageSessionDurationMinutes: 0,
      longestSessionMinutes: 0,
      averageFocusScore: 0,
      totalDistractionsCount: 0,
      dailyTrends: [],
      distractionBreakdown: [],
      subjectDistribution: [],
      goalsSummary: const GoalAnalyticsModel(
        totalGoals: 0,
        completedGoals: 0,
        activeGoals: 0,
        completionRatePercent: 0,
      ),
      streakSummary: const StudyStreakModel(
        currentStreakDays: 0,
        longestStreakDays: 0,
        studyDaysCount: 0,
        activeDaysPercent: 0,
      ),
    );
  }
}

void main() {
  group('M7 Analytics — Widget & UI Tests', () {
    testWidgets('AnalyticsPage renders metrics, timeline, and AI insight for active student', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AnalyticsPage(
              analyticsRepository: MockAnalyticsRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and time-range pills
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('7 Days'), findsOneWidget);
      expect(find.text('30 Days'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      // Check Key Metrics
      expect(find.text('Total Study Time'), findsOneWidget);
      expect(find.text('12h 35m'), findsOneWidget);
      expect(find.text('Sessions Completed'), findsOneWidget);
      expect(find.text('Average Focus'), findsOneWidget);
      expect(find.text('84%'), findsWidgets);
      expect(find.text('Consistency Score'), findsOneWidget);

      // Check AI Coach Intelligence Card
      expect(find.text('AI Coach Intelligence'), findsOneWidget);
      expect(find.textContaining('Strongest focus during morning sessions'), findsOneWidget);

      // Check Daily Timeline section
      expect(find.text('Daily Focus & Attention Trend'), findsOneWidget);

      // Check Distraction section
      expect(find.text('Distraction Telemetry Breakdown'), findsOneWidget);
      expect(find.text('Phone / Device Use'), findsOneWidget);

      // Check Subject Distribution and Goals
      expect(find.text('Subject Study Allocation'), findsOneWidget);
      expect(find.text('Deep Learning & Neural Networks'), findsOneWidget);
      expect(find.text('Goal Milestones'), findsOneWidget);
    });

    testWidgets('AnalyticsPage toggles time-range and renders empty state cleanly when no data exists', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AnalyticsPage(
              analyticsRepository: EmptyMockAnalyticsRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify empty state is displayed gracefully without confusing 0% claims
      expect(find.text('No study data for 7 Days'), findsOneWidget);

      // Switch to Today
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(find.text('No study data for Today'), findsOneWidget);
    });
  });
}
