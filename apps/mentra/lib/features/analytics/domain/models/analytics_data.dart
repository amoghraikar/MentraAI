enum AnalyticsTimeRange {
  today(label: 'Today', apiValue: 'today'),
  sevenDays(label: '7 Days', apiValue: '7d'),
  thirtyDays(label: '30 Days', apiValue: '30d');

  const AnalyticsTimeRange({required this.label, required this.apiValue});
  final String label;
  final String apiValue;
}

class DailyFocusMetricModel {
  const DailyFocusMetricModel({
    required this.dateKey,
    required this.dayLabel,
    required this.studyMinutes,
    required this.focusScore,
    required this.sessionsCount,
  });

  factory DailyFocusMetricModel.fromJson(Map<String, dynamic> json) {
    return DailyFocusMetricModel(
      dateKey: json['date_key'] as String? ?? '',
      dayLabel: json['day_label'] as String? ?? '',
      studyMinutes: (json['study_minutes'] as num?)?.toInt() ?? 0,
      focusScore: (json['focus_score'] as num?)?.toInt() ?? 0,
      sessionsCount: (json['sessions_count'] as num?)?.toInt() ?? 0,
    );
  }

  final String dateKey;
  final String dayLabel;
  final int studyMinutes;
  final int focusScore;
  final int sessionsCount;
}

class DistractionBreakdownItemModel {
  const DistractionBreakdownItemModel({
    required this.category,
    required this.count,
    required this.percentage,
    required this.trendLabel,
  });

  factory DistractionBreakdownItemModel.fromJson(Map<String, dynamic> json) {
    return DistractionBreakdownItemModel(
      category: json['category'] as String? ?? 'General Interruption',
      count: (json['count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toInt() ?? 0,
      trendLabel: json['trend_label'] as String? ?? 'Steady',
    );
  }

  final String category;
  final int count;
  final int percentage;
  final String trendLabel;
}

class SubjectStudyDistributionModel {
  const SubjectStudyDistributionModel({
    this.subjectId,
    required this.title,
    required this.colorHex,
    required this.totalMinutes,
    required this.sessionsCount,
    required this.percentage,
  });

  factory SubjectStudyDistributionModel.fromJson(Map<String, dynamic> json) {
    return SubjectStudyDistributionModel(
      subjectId: json['subject_id'] as String?,
      title: json['title'] as String? ?? 'Uncategorized',
      colorHex: json['color_hex'] as String? ?? '#6366F1',
      totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
      sessionsCount: (json['sessions_count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toInt() ?? 0,
    );
  }

  final String? subjectId;
  final String title;
  final String colorHex;
  final int totalMinutes;
  final int sessionsCount;
  final int percentage;

  String get formattedTime {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }
}

class GoalAnalyticsModel {
  const GoalAnalyticsModel({
    required this.totalGoals,
    required this.completedGoals,
    required this.activeGoals,
    required this.completionRatePercent,
  });

  factory GoalAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return GoalAnalyticsModel(
      totalGoals: (json['total_goals'] as num?)?.toInt() ?? 0,
      completedGoals: (json['completed_goals'] as num?)?.toInt() ?? 0,
      activeGoals: (json['active_goals'] as num?)?.toInt() ?? 0,
      completionRatePercent: (json['completion_rate_percent'] as num?)?.toInt() ?? 0,
    );
  }

  final int totalGoals;
  final int completedGoals;
  final int activeGoals;
  final int completionRatePercent;
}

class StudyStreakModel {
  const StudyStreakModel({
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.studyDaysCount,
    required this.activeDaysPercent,
  });

  factory StudyStreakModel.fromJson(Map<String, dynamic> json) {
    return StudyStreakModel(
      currentStreakDays: (json['current_streak_days'] as num?)?.toInt() ?? 0,
      longestStreakDays: (json['longest_streak_days'] as num?)?.toInt() ?? 0,
      studyDaysCount: (json['study_days_count'] as num?)?.toInt() ?? 0,
      activeDaysPercent: (json['active_days_percent'] as num?)?.toInt() ?? 0,
    );
  }

  final int currentStreakDays;
  final int longestStreakDays;
  final int studyDaysCount;
  final int activeDaysPercent;
}

class AnalyticsAiInsightModel {
  const AnalyticsAiInsightModel({
    required this.type,
    required this.insight,
    this.suggestedAction,
    required this.isActionable,
  });

  factory AnalyticsAiInsightModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsAiInsightModel(
      type: json['type'] as String? ?? 'general',
      insight: json['insight'] as String? ?? '',
      suggestedAction: json['suggested_action'] as String?,
      isActionable: json['is_actionable'] as bool? ?? false,
    );
  }

  final String type;
  final String insight;
  final String? suggestedAction;
  final bool isActionable;
}

class AnalyticsOverviewModel {
  const AnalyticsOverviewModel({
    required this.timeRange,
    required this.totalStudyMinutes,
    required this.totalStudyTimeFormatted,
    required this.totalSessionsCount,
    required this.completedSessionsCount,
    required this.averageSessionDurationMinutes,
    required this.longestSessionMinutes,
    required this.averageFocusScore,
    required this.totalDistractionsCount,
    required this.dailyTrends,
    required this.distractionBreakdown,
    required this.subjectDistribution,
    required this.goalsSummary,
    required this.streakSummary,
    this.aiInsight,
  });

  factory AnalyticsOverviewModel.fromJson(Map<String, dynamic> json) {
    final dailyList = (json['daily_trends'] as List<dynamic>? ?? [])
        .map((e) => DailyFocusMetricModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final distractionList = (json['distraction_breakdown'] as List<dynamic>? ?? [])
        .map((e) => DistractionBreakdownItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final subjectList = (json['subject_distribution'] as List<dynamic>? ?? [])
        .map((e) => SubjectStudyDistributionModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final goalsSummary = json['goals_summary'] != null
        ? GoalAnalyticsModel.fromJson(json['goals_summary'] as Map<String, dynamic>)
        : const GoalAnalyticsModel(
            totalGoals: 0,
            completedGoals: 0,
            activeGoals: 0,
            completionRatePercent: 0,
          );

    final streakSummary = json['streak_summary'] != null
        ? StudyStreakModel.fromJson(json['streak_summary'] as Map<String, dynamic>)
        : const StudyStreakModel(
            currentStreakDays: 0,
            longestStreakDays: 0,
            studyDaysCount: 0,
            activeDaysPercent: 0,
          );

    final aiInsight = json['ai_insight'] != null
        ? AnalyticsAiInsightModel.fromJson(json['ai_insight'] as Map<String, dynamic>)
        : null;

    return AnalyticsOverviewModel(
      timeRange: json['time_range'] as String? ?? '7d',
      totalStudyMinutes: (json['total_study_minutes'] as num?)?.toInt() ?? 0,
      totalStudyTimeFormatted: json['total_study_time_formatted'] as String? ?? '0h 0m',
      totalSessionsCount: (json['total_sessions_count'] as num?)?.toInt() ?? 0,
      completedSessionsCount: (json['completed_sessions_count'] as num?)?.toInt() ?? 0,
      averageSessionDurationMinutes: (json['average_session_duration_minutes'] as num?)?.toInt() ?? 0,
      longestSessionMinutes: (json['longest_session_minutes'] as num?)?.toInt() ?? 0,
      averageFocusScore: (json['average_focus_score'] as num?)?.toInt() ?? 0,
      totalDistractionsCount: (json['total_distractions_count'] as num?)?.toInt() ?? 0,
      dailyTrends: dailyList,
      distractionBreakdown: distractionList,
      subjectDistribution: subjectList,
      goalsSummary: goalsSummary,
      streakSummary: streakSummary,
      aiInsight: aiInsight,
    );
  }

  final String timeRange;
  final int totalStudyMinutes;
  final String totalStudyTimeFormatted;
  final int totalSessionsCount;
  final int completedSessionsCount;
  final int averageSessionDurationMinutes;
  final int longestSessionMinutes;
  final int averageFocusScore;
  final int totalDistractionsCount;
  final List<DailyFocusMetricModel> dailyTrends;
  final List<DistractionBreakdownItemModel> distractionBreakdown;
  final List<SubjectStudyDistributionModel> subjectDistribution;
  final GoalAnalyticsModel goalsSummary;
  final StudyStreakModel streakSummary;
  final AnalyticsAiInsightModel? aiInsight;

  List<DailyFocusMetricModel> get weeklyTrends => dailyTrends;
  int get consistencyScore => streakSummary.activeDaysPercent;
  bool get hasData => totalSessionsCount > 0 || totalStudyMinutes > 0;
}

// Backward compatibility classes
typedef DailyFocusTrend = DailyFocusMetricModel;
typedef DistractionCategory = DistractionBreakdownItemModel;
typedef AnalyticsSummaryModel = AnalyticsOverviewModel;
