import '../models/goal_model.dart';

abstract class GoalRepository {
  Future<List<GoalModel>> getGoals();
  Future<GoalModel> createGoal({
    required String title,
    required String subjectTitle,
    required DateTime targetDate,
    List<String> milestoneTitles = const [],
  });
  Future<GoalModel> updateGoal(GoalModel goal);
  Future<GoalModel> toggleMilestone(String goalId, String milestoneId);
  Future<void> deleteGoal(String id);
}
