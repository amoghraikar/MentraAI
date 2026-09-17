import '../../domain/models/analytics_data.dart';
import '../../domain/repositories/analytics_repository.dart';

class MockAnalyticsRepository implements AnalyticsRepository {
  @override
  Future<AnalyticsOverviewModel> getAnalyticsSummary({
    AnalyticsTimeRange timeRange = AnalyticsTimeRange.sevenDays,
  }) async {
    return const AnalyticsOverviewModel(
      timeRange: '7d',
      totalStudyMinutes: 755,
      totalStudyTimeFormatted: '12h 35m',
      totalSessionsCount: 18,
      completedSessionsCount: 16,
      averageSessionDurationMinutes: 42,
      longestSessionMinutes: 90,
      averageFocusScore: 84,
      totalDistractionsCount: 29,
      dailyTrends: [
        DailyFocusMetricModel(dateKey: '2026-09-11', dayLabel: 'Mon', studyMinutes: 135, focusScore: 88, sessionsCount: 3),
        DailyFocusMetricModel(dateKey: '2026-09-12', dayLabel: 'Tue', studyMinutes: 110, focusScore: 82, sessionsCount: 2),
        DailyFocusMetricModel(dateKey: '2026-09-13', dayLabel: 'Wed', studyMinutes: 160, focusScore: 89, sessionsCount: 4),
        DailyFocusMetricModel(dateKey: '2026-09-14', dayLabel: 'Thu', studyMinutes: 90, focusScore: 78, sessionsCount: 2),
        DailyFocusMetricModel(dateKey: '2026-09-15', dayLabel: 'Fri', studyMinutes: 145, focusScore: 86, sessionsCount: 3),
        DailyFocusMetricModel(dateKey: '2026-09-16', dayLabel: 'Sat', studyMinutes: 75, focusScore: 80, sessionsCount: 2),
        DailyFocusMetricModel(dateKey: '2026-09-17', dayLabel: 'Sun', studyMinutes: 40, focusScore: 84, sessionsCount: 2),
      ],
      distractionBreakdown: [
        DistractionBreakdownItemModel(category: 'Phone / Device Use', percentage: 48, count: 14, trendLabel: '-12% this week'),
        DistractionBreakdownItemModel(category: 'Drowsiness / Fatigue', percentage: 26, count: 8, trendLabel: 'Steady'),
        DistractionBreakdownItemModel(category: 'Looking Away / Multitasking', percentage: 18, count: 5, trendLabel: '-5% this week'),
        DistractionBreakdownItemModel(category: 'Other Interruptions', percentage: 8, count: 2, trendLabel: '-20% this week'),
      ],
      subjectDistribution: [
        SubjectStudyDistributionModel(
          subjectId: 'sub-1',
          title: 'Deep Learning & Neural Networks',
          colorHex: '#6366F1',
          totalMinutes: 380,
          sessionsCount: 8,
          percentage: 50,
        ),
        SubjectStudyDistributionModel(
          subjectId: 'sub-2',
          title: 'Algorithms & Data Structures',
          colorHex: '#10B981',
          totalMinutes: 225,
          sessionsCount: 6,
          percentage: 30,
        ),
        SubjectStudyDistributionModel(
          subjectId: 'sub-3',
          title: 'Distributed Systems',
          colorHex: '#F59E0B',
          totalMinutes: 150,
          sessionsCount: 4,
          percentage: 20,
        ),
      ],
      goalsSummary: GoalAnalyticsModel(
        totalGoals: 5,
        completedGoals: 3,
        activeGoals: 2,
        completionRatePercent: 60,
      ),
      streakSummary: StudyStreakModel(
        currentStreakDays: 5,
        longestStreakDays: 9,
        studyDaysCount: 6,
        activeDaysPercent: 85,
      ),
      aiInsight: AnalyticsAiInsightModel(
        type: 'Consistency & Focus',
        insight: 'Strongest focus during morning sessions with highest attention on Deep Learning. Distraction peaks after 45 continuous minutes.',
        suggestedAction: 'Schedule a 5-minute cognitive reset after 40 minutes of deep study.',
        isActionable: true,
      ),
    );
  }
}
