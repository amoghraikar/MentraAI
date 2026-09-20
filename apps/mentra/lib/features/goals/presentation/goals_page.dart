import 'package:flutter/material.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/dialogs/mentra_dialogs.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_empty_state.dart';
import '../../../shared/widgets/mentra_page_header.dart';
import '../../../shared/widgets/mentra_progress_bar.dart';
import '../domain/models/goal_model.dart';
import '../domain/repositories/goal_repository.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({
    super.key,
    required this.goalRepository,
  });

  final GoalRepository goalRepository;

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  List<GoalModel> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    try {
      final list = await widget.goalRepository.getGoals();
      if (!mounted) return;
      setState(() {
        _goals = list;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _goals = [];
        _isLoading = false;
      });
    }
  }

  void _showNewGoalDialog() async {
    final titleCtrl = TextEditingController();
    String subject = 'Data Analytics';
    final m1Ctrl = TextEditingController();
    final m2Ctrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
        title: const Text('Create Study Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Goal Title', style: AppTypography.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(hintText: 'e.g. Master Linear Regression & OLS'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Subject', style: AppTypography.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<String>(
              initialValue: subject,
              items: ['Data Analytics', 'Software Engineering', 'Web Programming']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => subject = v ?? subject,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Milestone 1', style: AppTypography.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: m1Ctrl,
              decoration: const InputDecoration(hintText: 'e.g. Complete 5 practice problem sets'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Milestone 2', style: AppTypography.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: m2Ctrl,
              decoration: const InputDecoration(hintText: 'e.g. Conduct residual ANOVA diagnostics'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          MentraButton(
            label: 'Create Goal',
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              }
            },
          ),
        ],
      ),
    );

    if (result == true && titleCtrl.text.trim().isNotEmpty) {
      await widget.goalRepository.createGoal(
        title: titleCtrl.text.trim(),
        subjectTitle: subject,
        targetDate: DateTime.now().add(const Duration(days: 14)),
        milestoneTitles: [
          if (m1Ctrl.text.trim().isNotEmpty) m1Ctrl.text.trim(),
          if (m2Ctrl.text.trim().isNotEmpty) m2Ctrl.text.trim(),
        ],
      );
      _loadGoals();
    }
  }

  void _deleteGoal(GoalModel goal) async {
    final confirmed = await MentraConfirmDialog.show(
      context: context,
      title: 'Delete Goal?',
      message: 'Are you sure you want to delete this study goal?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed) {
      await widget.goalRepository.deleteGoal(goal.id);
      _loadGoals();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MentraPageHeader(
          title: 'Goals',
          subtitle: 'Track learning milestones, exam preparation, and study targets',
          action: MentraButton(
            label: 'New Goal',
            icon: Icons.add_rounded,
            onPressed: _showNewGoalDialog,
          ),
        ),

        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_goals.isEmpty)
          MentraEmptyState(
            icon: Icons.flag_outlined,
            title: 'No study goals yet',
            description: 'Set a goal to break down your coursework into structured milestones.',
            actionLabel: 'Set First Goal',
            onAction: _showNewGoalDialog,
          )
        else
          Column(
            children: _goals.map((goal) {
              final daysLeft = goal.targetDate.difference(DateTime.now()).inDays;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: MentraCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              MentraBadge(
                                label: goal.subjectTitle,
                                variant: MentraBadgeVariant.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                daysLeft > 0 ? '$daysLeft days left' : 'Due today',
                                style: AppTypography.labelSmall.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                            tooltip: 'Delete Goal',
                            onPressed: () => _deleteGoal(goal),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        goal.title,
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      MentraProgressBar(
                        value: goal.progress,
                        label: '${(goal.progress * 100).toInt()}% Completed',
                        valueLabel: '${goal.milestones.where((m) => m.isCompleted).length}/${goal.milestones.length} Milestones',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Divider(color: theme.dividerColor, height: 1),
                      const SizedBox(height: AppSpacing.md),
                      // Milestones List
                      Column(
                        children: goal.milestones.map((m) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: m.isCompleted,
                                  onChanged: (_) async {
                                    await widget.goalRepository.toggleMilestone(goal.id, m.id);
                                    _loadGoals();
                                  },
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    m.title,
                                    style: AppTypography.bodySmall.copyWith(
                                      decoration: m.isCompleted ? TextDecoration.lineThrough : null,
                                      color: m.isCompleted
                                          ? theme.colorScheme.onSurfaceVariant
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
