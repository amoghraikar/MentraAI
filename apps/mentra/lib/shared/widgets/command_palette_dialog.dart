import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/routing/app_route.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/theme_controller.dart';

class CommandItem {
  const CommandItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onSelected,
    this.category = 'Navigation',
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onSelected;
  final String category;
  final String? badge;
}

class CommandPaletteDialog extends StatefulWidget {
  const CommandPaletteDialog({
    super.key,
    required this.onStartStudySession,
  });

  final VoidCallback onStartStudySession;

  static Future<void> show(BuildContext context, {required VoidCallback onStartStudySession}) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => CommandPaletteDialog(onStartStudySession: onStartStudySession),
    );
  }

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<CommandItem> _getAllCommands(BuildContext context) {
    final nav = NavigationScope.of(context);
    final themeCtrl = ThemeScope.of(context);

    return [
      // Quick Actions
      CommandItem(
        title: 'Start Study & Focus Session',
        subtitle: 'Configure subject, topic and start on-device focus tracking',
        icon: Icons.play_arrow_rounded,
        category: 'Quick Actions',
        badge: 'Recommended',
        onSelected: () {
          Navigator.of(context).pop();
          widget.onStartStudySession();
        },
      ),
      CommandItem(
        title: 'Ask Mentra AI',
        subtitle: 'Open private local study coach conversation',
        icon: Icons.psychology_outlined,
        category: 'Quick Actions',
        onSelected: () {
          Navigator.of(context).pop();
          nav.setRoute(AppRoute.aiCoach);
        },
      ),
      CommandItem(
        title: 'Toggle Color Theme',
        subtitle: 'Switch between light and dark workspace theme',
        icon: Icons.contrast_rounded,
        category: 'Quick Actions',
        onSelected: () {
          Navigator.of(context).pop();
          themeCtrl.toggleTheme();
        },
      ),

      // Workspace Pages
      CommandItem(
        title: 'Home Workspace',
        subtitle: 'Today overview, recent sessions, and learning metrics',
        icon: Icons.home_outlined,
        category: 'Workspace',
        onSelected: () {
          Navigator.of(context).pop();
          nav.setRoute(AppRoute.home);
        },
      ),
      CommandItem(
        title: 'Study & Coursework',
        subtitle: 'Curriculum subjects, topics, and checkpoints',
        icon: Icons.auto_stories_outlined,
        category: 'Workspace',
        onSelected: () {
          Navigator.of(context).pop();
          nav.setRoute(AppRoute.subjects);
        },
      ),
      CommandItem(
        title: 'Notes & Documents',
        subtitle: 'Lecture summaries, markdown notes, and checkpoints',
        icon: Icons.description_outlined,
        category: 'Workspace',
        onSelected: () {
          Navigator.of(context).pop();
          nav.setRoute(AppRoute.notes);
        },
      ),
      CommandItem(
        title: 'Goals & Milestones',
        subtitle: 'Academic targets, exams, and milestones',
        icon: Icons.flag_outlined,
        category: 'Workspace',
        onSelected: () {
          Navigator.of(context).pop();
          nav.setRoute(AppRoute.goals);
        },
      ),
      CommandItem(
        title: 'Focus Telemetry & Camera',
        subtitle: 'Real-time computer vision and distraction detection',
        icon: Icons.center_focus_strong_outlined,
        category: 'Insights',
        onSelected: () {
          Navigator.of(context).pop();
          nav.setRoute(AppRoute.focus);
        },
      ),
      CommandItem(
        title: 'Progress & Analytics',
        subtitle: 'Historical attention trends, session logs, and distraction stats',
        icon: Icons.insights_outlined,
        category: 'Insights',
        onSelected: () {
          Navigator.of(context).pop();
          nav.setRoute(AppRoute.analytics);
        },
      ),
      CommandItem(
        title: 'Workspace Settings',
        subtitle: 'Appearance, local AI model, privacy, and permissions',
        icon: Icons.tune_outlined,
        category: 'System',
        onSelected: () {
          Navigator.of(context).pop();
          nav.setRoute(AppRoute.settings);
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final query = _searchController.text.trim().toLowerCase();

    final allCommands = _getAllCommands(context);
    final filteredCommands = allCommands.where((cmd) {
      if (query.isEmpty) return true;
      return cmd.title.toLowerCase().contains(query) ||
          cmd.subtitle.toLowerCase().contains(query) ||
          cmd.category.toLowerCase().contains(query);
    }).toList();

    if (_selectedIndex >= filteredCommands.length) {
      _selectedIndex = filteredCommands.isEmpty ? 0 : filteredCommands.length - 1;
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).pop();
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          if (filteredCommands.isNotEmpty) {
            setState(() {
              _selectedIndex = (_selectedIndex + 1) % filteredCommands.length;
            });
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          if (filteredCommands.isNotEmpty) {
            setState(() {
              _selectedIndex = (_selectedIndex - 1 + filteredCommands.length) % filteredCommands.length;
            });
          }
        },
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (filteredCommands.isNotEmpty && _selectedIndex < filteredCommands.length) {
            filteredCommands[_selectedIndex].onSelected();
          }
        },
      },
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 580,
            constraints: const BoxConstraints(maxHeight: 460),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightCard,
              borderRadius: AppRadius.borderLg,
              border: Border.all(
                color: isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Search Input
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          style: AppTypography.bodyMedium.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search or jump to workspace...',
                            hintStyle: AppTypography.bodyMedium.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) {
                            setState(() {
                              _selectedIndex = 0;
                            });
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2E2E2A) : const Color(0xFFEAEAE8),
                          borderRadius: AppRadius.borderSm,
                        ),
                        child: Text(
                          'ESC',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: theme.dividerColor, height: 1),

                // Results List
                Flexible(
                  child: filteredCommands.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Center(
                            child: Text(
                              'No matching commands found',
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          itemCount: filteredCommands.length,
                          itemBuilder: (context, index) {
                            final cmd = filteredCommands[index];
                            final isSelected = index == _selectedIndex;

                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) => setState(() => _selectedIndex = index),
                              child: GestureDetector(
                                onTap: cmd.onSelected,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs + 2,
                                    vertical: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (isDark ? const Color(0xFF2C2C28) : const Color(0xFFEFEFEA))
                                        : Colors.transparent,
                                    borderRadius: AppRadius.borderSm,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        cmd.icon,
                                        size: 18,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              cmd.title,
                                              style: AppTypography.bodyMedium.copyWith(
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            Text(
                                              cmd.subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.bodySmall.copyWith(
                                                fontSize: 11,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (cmd.badge != null) ...[
                                        const SizedBox(width: AppSpacing.xs),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primarySoft,
                                            borderRadius: AppRadius.borderSm,
                                          ),
                                          child: Text(
                                            cmd.badge!,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (isSelected) ...[
                                        const SizedBox(width: AppSpacing.xs),
                                        Icon(
                                          Icons.keyboard_return_rounded,
                                          size: 14,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Bottom Shortcuts Hint
                Divider(color: theme.dividerColor, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildKeyHint('↑↓', 'Navigate', theme, isDark),
                          const SizedBox(width: AppSpacing.md),
                          _buildKeyHint('↵', 'Select', theme, isDark),
                        ],
                      ),
                      Text(
                        'Mentra Workspace',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyHint(String key, String label, ThemeData theme, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2E2E2A) : const Color(0xFFEAEAE8),
            borderRadius: AppRadius.borderSm,
          ),
          child: Text(
            key,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
