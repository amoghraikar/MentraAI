import 'dart:math';
import '../../domain/models/goal_model.dart';
import '../../domain/repositories/goal_repository.dart';

class MockGoalRepository implements GoalRepository {
  MockGoalRepository() {
    _initDefaults();
  }

  final List<GoalModel> _goals = [];

  void _initDefaults() {
    final now = DateTime.now();
    _goals.addAll([
      GoalModel(
        id: 'goal_1',
        title: 'Complete Data Analytics Unit II & OLS Mastery',
        subjectTitle: 'Data Analytics',
        targetDate: now.add(const Duration(days: 12)),
        milestones: const [
          GoalMilestone(id: 'm1_1', title: 'Complete Pearson & Spearman covariance notes', isCompleted: true),
          GoalMilestone(id: 'm1_2', title: 'Solve 15 multiple regression problem sets', isCompleted: true),
          GoalMilestone(id: 'm1_3', title: 'Conduct ANOVA F-test residual diagnostics', isCompleted: false),
          GoalMilestone(id: 'm1_4', title: 'Score > 85% on unit mock exam', isCompleted: false),
        ],
      ),
      GoalModel(
        id: 'goal_2',
        title: 'Complete Software Engineering System Architecture Revision',
        subjectTitle: 'Software Engineering',
        targetDate: now.add(const Duration(days: 18)),
        milestones: const [
          GoalMilestone(id: 'm2_1', title: 'Review 4 Agile scrum ceremonies & sprint cadence', isCompleted: true),
          GoalMilestone(id: 'm2_2', title: 'Diagram Clean Architecture boundary dependencies', isCompleted: true),
          GoalMilestone(id: 'm2_3', title: 'Implement TDD red-green refactor workshop', isCompleted: false),
        ],
      ),
      GoalModel(
        id: 'goal_3',
        title: 'Build Web Programming Portfolio & CSS Grid Layouts',
        subjectTitle: 'Web Programming',
        targetDate: now.add(const Duration(days: 25)),
        milestones: const [
          GoalMilestone(id: 'm3_1', title: 'Master CSS Grid auto-fit template areas', isCompleted: true),
          GoalMilestone(id: 'm3_2', title: 'Complete JavaScript ES6+ async/await modules', isCompleted: false),
          GoalMilestone(id: 'm3_3', title: 'Publish responsive personal workspace demo', isCompleted: false),
        ],
      ),
    ]);
  }

  @override
  Future<List<GoalModel>> getGoals() async {
    return List.unmodifiable(_goals);
  }

  @override
  Future<GoalModel> createGoal({
    required String title,
    required String subjectTitle,
    required DateTime targetDate,
    List<String> milestoneTitles = const [],
  }) async {
    final milestones = milestoneTitles
        .where((t) => t.trim().isNotEmpty)
        .map((t) => GoalMilestone(
              id: 'm_${Random().nextInt(999999)}',
              title: t.trim(),
              isCompleted: false,
            ))
        .toList();

    final goal = GoalModel(
      id: 'goal_${Random().nextInt(999999)}',
      title: title,
      subjectTitle: subjectTitle,
      targetDate: targetDate,
      milestones: milestones,
    );
    _goals.insert(0, goal);
    return goal;
  }

  @override
  Future<GoalModel> updateGoal(GoalModel goal) async {
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index != -1) {
      _goals[index] = goal;
      return goal;
    }
    throw Exception('Goal not found');
  }

  @override
  Future<GoalModel> toggleMilestone(String goalId, String milestoneId) async {
    final goalIndex = _goals.indexWhere((g) => g.id == goalId);
    if (goalIndex == -1) throw Exception('Goal not found');

    final goal = _goals[goalIndex];
    final updatedMilestones = goal.milestones.map((m) {
      if (m.id == milestoneId) {
        return m.copyWith(isCompleted: !m.isCompleted);
      }
      return m;
    }).toList();

    final allDone = updatedMilestones.isNotEmpty && updatedMilestones.every((m) => m.isCompleted);
    final updatedGoal = goal.copyWith(
      milestones: updatedMilestones,
      isCompleted: allDone,
    );
    _goals[goalIndex] = updatedGoal;
    return updatedGoal;
  }

  @override
  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
  }
}
