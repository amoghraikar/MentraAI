import 'package:flutter/material.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../subjects/domain/models/subject_model.dart';
import '../../subjects/domain/models/topic_model.dart';
import '../../subjects/domain/repositories/subject_repository.dart';
import '../domain/models/session_config.dart';

class StudySetupDialog extends StatefulWidget {
  const StudySetupDialog({
    super.key,
    required this.subjectRepository,
    required this.onStartPreparation,
    this.initialSubjectId,
    this.initialTopicId,
  });

  final SubjectRepository subjectRepository;
  final ValueChanged<SessionConfig> onStartPreparation;
  final String? initialSubjectId;
  final String? initialTopicId;

  static final SubjectModel defaultGeneralSubject = SubjectModel(
    id: 'general_study',
    title: 'General Focus & Deep Work',
    code: 'FOCUS',
    description: 'General open study session',
    colorHex: '#6366F1',
    totalHours: 0.0,
    targetHours: 20.0,
    topics: const [
      TopicModel(
        id: 'general_topic',
        subjectId: 'general_study',
        title: 'General Coursework',
        description: 'Open study focus block',
        progress: 0.0,
        totalMinutes: 0,
        keyConcepts: [],
        notesSnippet: '',
        isCompleted: false,
      ),
    ],
  );

  static Future<void> show({
    required BuildContext context,
    required SubjectRepository subjectRepository,
    required ValueChanged<SessionConfig> onStartPreparation,
    String? initialSubjectId,
    String? initialTopicId,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StudySetupDialog(
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
    List<SubjectModel> list = [];
    try {
      list = await widget.subjectRepository.getSubjects();
    } catch (_) {
      list = [];
    }
    if (!mounted) return;
    setState(() {
      _subjects = list.isNotEmpty ? list : [StudySetupDialog.defaultGeneralSubject];
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
      } else {
        _selectedTopic = null;
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
    final effectiveSubject = _selectedSubject ??
        (_subjects.isNotEmpty ? _subjects.first : StudySetupDialog.defaultGeneralSubject);

    final config = SessionConfig(
      subjectId: effectiveSubject.id,
      subjectTitle: effectiveSubject.title,
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
                                '${d}m',
                                style: AppTypography.labelSmall.copyWith(
                                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Mode Radio / Chips
                    Text('Mode', style: AppTypography.labelSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: _modes.map((m) {
                        final isSelected = _selectedMode == m;
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedMode = m),
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
                                m,
                                style: AppTypography.labelSmall.copyWith(
                                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // On-device focus monitoring toggle
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F6),
                        borderRadius: AppRadius.borderSm,
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'On-Device Focus Monitoring',
                                  style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600),
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
