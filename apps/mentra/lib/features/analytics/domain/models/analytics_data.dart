class DailyFocusTrend {
  const DailyFocusTrend({
    required this.dayLabel,
    required this.studyMinutes,
    required this.focusScore,
  });

  final String dayLabel;
  final int studyMinutes;
  final int focusScore;
}

class DistractionCategory {
  const DistractionCategory({
    required this.name,
    required this.percentage,
    required this.count,
    required this.trendLabel,
  });

  final String name;
  final int percentage;
  final int count;
  final String trendLabel;
}

class AnalyticsSummaryModel {
  const AnalyticsSummaryModel({
    required this.totalStudyTimeFormatted,
    required this.totalSessionsCount,
    required this.averageFocusScore,
    required this.consistencyScore,
    required this.weeklyTrends,
    required this.distractionBreakdown,
  });

  final String totalStudyTimeFormatted;
  final int totalSessionsCount;
  final int averageFocusScore;
  final int consistencyScore;
  final List<DailyFocusTrend> weeklyTrends;
  final List<DistractionCategory> distractionBreakdown;
}
