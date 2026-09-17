import '../models/analytics_data.dart';

abstract class AnalyticsRepository {
  Future<AnalyticsOverviewModel> getAnalyticsSummary({
    AnalyticsTimeRange timeRange = AnalyticsTimeRange.sevenDays,
  });
}
