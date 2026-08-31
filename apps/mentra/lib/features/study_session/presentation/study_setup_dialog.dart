import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../subjects/domain/models/subject_model.dart';
import '../../subjects/domain/models/topic_model.dart';
import '../../subjects/domain/repositories/subject_repository.dart';
import '../domain/models/session_config.dart';

class StudySetupDialog extends StatefulWidget {
  const StudySetupDialog({
    super.key,
    required this.subjectRepository,
    this.initialSubjectId,
    this.initialTopicId,
    required this.onStartPreparation,
  });

  final SubjectRepository subjectRepository;
  final String? initialSubjectId;
  final String? initialTopicId;
  final void Function(SessionConfig config) onStartPreparation;

  static Future<void> show({
    required BuildContext context,
    required SubjectRepository subjectRepository,
    String? initialSubjectId,
    String? initialTopicId,
    required void Function(SessionConfig config) onStartPreparation,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => StudySetupDialog(
        subjectRepository: subjectRepository,
        initialSubjectId: initialSubjectId,
        initialTopicId: initialTopicId,
        onStartPreparation: onStartPreparation,
      ),
    );
  }

  @override
  State<StudySetupDialog> createState() => _StudySetupDialogState();
}

class _StudySetupDialogState extends State<StudySetupDialog> {
  List<SubjectModel> _subjects = [];
  bool _isLoading = true;

  SubjectModel? _selectedSubject;
  TopicModel? _selectedTopic;
  int _selectedDuration = 45;
  String _selectedMode = 'Focus Mode';
  bool _monitoringEnabled = true;

  final List<int> _durations = [15, 25, 45, 50, 60, 90];
  final List<String> _modes = ['Focus Mode', 'Deep Work', 'Rapid Review'];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final list = await widget.subjectRepository.getSubjects();
    if (!mounted) return;
    setState(() {
      _subjects = list;
      if (_subjects.isNotEmpty) {
        if (widget.initialSubjectId != null) {
          _selectedSubject = _subjects.firstWhere(
            (s) => s.id == widget.initialSubjectId,
            orElse: () => _subjects.first,
          );
        } else {
          _selectedSubject = _subjects.first;
        }

        if (_selectedSubject!.topics.isNotEmpty) {
          if (widget.initialTopicId != null) {
            _selectedTopic = _selectedSubject!.topics.firstWhere(
              (t) => t.id == widget.initialTopicId,
              orElse: () => _selectedSubject!.topics.first,
            );
          } else {
            _selectedTopic = _selectedSubject!.topics.first;
          }
        }
      }
      _isLoading = false;
    });
  }

  void _onSubjectChanged(SubjectModel? subject) {
    if (subject == null) return;
    setState(() {
      _selectedSubject = subject;
      _selectedTopic = subject.topics.isNotEmpty ? subject.topics.first : null;
    });
  }

  void _submit() {
    if (_selectedSubject == null) return;

    final config = SessionConfig(
      subjectId: _selectedSubject!.id,
      subjectTitle: _selectedSubject!.title,
      topicId: _selectedTopic?.id ?? 'gen_top',
      topicTitle: _selectedTopic?.title ?? 'General Coursework',
      targetDurationMinutes: _selectedDuration,
      studyMode: _selectedMode,
      isFocusMonitoringEnabled: _monitoringEnabled,
    );

    Navigator.of(context).pop();
    widget.onStartPreparation(config);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: _isLoading
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start a study session',
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                'Configure your focus parameters',
                                style: AppTypography.bodySmall.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    Divider(color: theme.dividerColor, height: 1),
                    const SizedBox(height: AppSpacing.lg),

                    // Subject Dropdown
                    Text('Subject', style: AppTypography.labelSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222222) : const Color(0xFFF6F6F4),
                        borderRadius: AppRadius.borderSm,
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<SubjectModel>(
                          value: _selectedSubject,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                          dropdownColor: theme.colorScheme.surface,
                          items: _subjects.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(s.title, style: AppTypography.bodyMedium),
                            );
                          }).toList(),
                          onChanged: _onSubjectChanged,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Topic Dropdown
                    Text('Topic', style: AppTypography.labelSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222222) : const Color(0xFFF6F6F4),
                        borderRadius: AppRadius.borderSm,
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TopicModel>(
                          value: _selectedTopic,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                          dropdownColor: theme.colorScheme.surface,
                          items: (_selectedSubject?.topics ?? []).map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text(t.title, style: AppTypography.bodyMedium),
                            );
                          }).toList(),
                          onChanged: (t) => setState(() => _selectedTopic = t),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Duration Selector Chips
                    Text('Duration', style: AppTypography.labelSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: _durations.map((d) {
                        final isSelected = _selectedDuration == d;
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedDuration = d),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                                    : (isDark ? const Color(0xFF222222) : const Color(0xFFF2F2F0)),
                                borderRadius: AppRadius.borderSm,
                                border: Border.all(
                                  color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                '$d min',
                                style: AppTypography.labelSmall.copyWith(
                                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Study Mode Chips
                    Text('Study Mode', style: AppTypography.labelSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: _modes.map((m) {
                        final isSelected = _selectedMode == m;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedMode = m),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                                        : (isDark ? const Color(0xFF222222) : const Color(0xFFF2F2F0)),
                                    borderRadius: AppRadius.borderSm,
                                    border: Border.all(
                                      color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    m,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Focus Monitoring Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F8),
                        borderRadius: AppRadius.borderSm,
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: AppColors.success, size: 20),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Mentra Focus Monitoring',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.labelMedium,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    const MentraBadge(label: 'On-Device', variant: MentraBadgeVariant.success),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  'Analyzes attention, phone pickups, and fatigue locally without storing video footage.',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _monitoringEnabled,
                            onChanged: (v) => setState(() => _monitoringEnabled = v),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Begin Session CTA
                    MentraButton(
                      label: 'Begin Session',
                      icon: Icons.play_arrow_rounded,
                      fullWidth: true,
                      onPressed: _submit,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
