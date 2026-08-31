import '../models/analytics_data.dart';

abstract class AnalyticsRepository {
  Future<AnalyticsSummaryModel> getAnalyticsSummary();
}
