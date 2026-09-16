import '../../../../core/network/api_client.dart';
import '../../domain/models/analytics_data.dart';
import '../../domain/repositories/analytics_repository.dart';

class ApiAnalyticsRepository implements AnalyticsRepository {
  ApiAnalyticsRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<AnalyticsSummaryModel> getAnalyticsSummary() async {
    final response = await apiClient.get(
      '/api/v1/sessions',
      queryParams: {'limit': '50'},
    );
    final sessions = response as List<dynamic>;

    if (sessions.isEmpty) {
      return AnalyticsSummaryModel(
        totalStudyTimeFormatted: '0h 0m',
        totalSessionsCount: 0,
        averageFocusScore: 0,
        consistencyScore: 0,
        weeklyTrends: [
          const DailyFocusTrend(dayLabel: 'Mon', studyMinutes: 0, focusScore: 0),
          const DailyFocusTrend(dayLabel: 'Tue', studyMinutes: 0, focusScore: 0),
          const DailyFocusTrend(dayLabel: 'Wed', studyMinutes: 0, focusScore: 0),
          const DailyFocusTrend(dayLabel: 'Thu', studyMinutes: 0, focusScore: 0),
          const DailyFocusTrend(dayLabel: 'Fri', studyMinutes: 0, focusScore: 0),
          const DailyFocusTrend(dayLabel: 'Sat', studyMinutes: 0, focusScore: 0),
          const DailyFocusTrend(dayLabel: 'Sun', studyMinutes: 0, focusScore: 0),
        ],
        distractionBreakdown: [
          const DistractionCategory(
            name: 'Phone / Device',
            percentage: 0,
            count: 0,
            trendLabel: '0 distractions',
          ),
          const DistractionCategory(
            name: 'Looking Away / Multitasking',
            percentage: 0,
            count: 0,
            trendLabel: '0 distractions',
          ),
          const DistractionCategory(
            name: 'Drowsiness / Fatigue',
            percentage: 0,
            count: 0,
            trendLabel: '0 distractions',
          ),
        ],
      );
    }

    int totalMinutes = 0;
    int totalFocus = 0;
    int totalDistractions = 0;

    for (final s in sessions) {
      final map = s as Map<String, dynamic>;
      final mins = (map['actual_duration_minutes'] as num?)?.toInt() ?? 0;
      final score = (map['focus_score'] as num?)?.toInt() ?? 100;
      final dist = (map['distractions_count'] as num?)?.toInt() ?? 0;
      totalMinutes += mins;
      totalFocus += score;
      totalDistractions += dist;
    }

    final avgFocus = (totalFocus / sessions.length).round();
    final hours = totalMinutes ~/ 60;
    final remainingMins = totalMinutes % 60;
    final formattedTime = '${hours}h ${remainingMins}m';

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weeklyTrends = days.map((day) {
      return DailyFocusTrend(
        dayLabel: day,
        studyMinutes: (totalMinutes / 7).round(),
        focusScore: avgFocus,
      );
    }).toList();

    final phoneDist = (totalDistractions * 0.55).round();
    final lookDist = (totalDistractions * 0.30).round();
    final fatigueDist = totalDistractions - phoneDist - lookDist;

    final distractionBreakdown = [
      DistractionCategory(
        name: 'Phone / Device',
        percentage: totalDistractions > 0 ? ((phoneDist / totalDistractions) * 100).round() : 0,
        count: phoneDist,
        trendLabel: '$phoneDist occurrences',
      ),
      DistractionCategory(
        name: 'Looking Away / Multitasking',
        percentage: totalDistractions > 0 ? ((lookDist / totalDistractions) * 100).round() : 0,
        count: lookDist,
        trendLabel: '$lookDist occurrences',
      ),
      DistractionCategory(
        name: 'Drowsiness / Fatigue',
        percentage: totalDistractions > 0 ? ((fatigueDist / totalDistractions) * 100).round() : 0,
        count: fatigueDist,
        trendLabel: '$fatigueDist occurrences',
      ),
    ];

    return AnalyticsSummaryModel(
      totalStudyTimeFormatted: formattedTime,
      totalSessionsCount: sessions.length,
      averageFocusScore: avgFocus,
      consistencyScore: (avgFocus * 0.95).round().clamp(0, 100),
      weeklyTrends: weeklyTrends,
      distractionBreakdown: distractionBreakdown,
    );
  }
}
