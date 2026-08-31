import '../../domain/models/analytics_data.dart';
import '../../domain/repositories/analytics_repository.dart';

class MockAnalyticsRepository implements AnalyticsRepository {
  @override
  Future<AnalyticsSummaryModel> getAnalyticsSummary() async {
    return const AnalyticsSummaryModel(
      totalStudyTimeFormatted: '12h 35m',
      totalSessionsCount: 18,
      averageFocusScore: 84,
      consistencyScore: 76,
      weeklyTrends: [
        DailyFocusTrend(dayLabel: 'Mon', studyMinutes: 135, focusScore: 88),
        DailyFocusTrend(dayLabel: 'Tue', studyMinutes: 110, focusScore: 82),
        DailyFocusTrend(dayLabel: 'Wed', studyMinutes: 160, focusScore: 89),
        DailyFocusTrend(dayLabel: 'Thu', studyMinutes: 90, focusScore: 78),
        DailyFocusTrend(dayLabel: 'Fri', studyMinutes: 145, focusScore: 86),
        DailyFocusTrend(dayLabel: 'Sat', studyMinutes: 75, focusScore: 80),
        DailyFocusTrend(dayLabel: 'Sun', studyMinutes: 40, focusScore: 84),
      ],
      distractionBreakdown: [
        DistractionCategory(name: 'Phone / Social Media', percentage: 48, count: 14, trendLabel: '-12% this week'),
        DistractionCategory(name: 'Drowsiness / Fatigue', percentage: 26, count: 8, trendLabel: 'Steady'),
        DistractionCategory(name: 'Looking Away / Gaze', percentage: 18, count: 5, trendLabel: '-5% this week'),
        DistractionCategory(name: 'Other Environmental', percentage: 8, count: 2, trendLabel: '-20% this week'),
      ],
    );
  }
}
