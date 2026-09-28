import 'package:flutter/material.dart';
import '../../core/routing/app_route.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/study_session/presentation/session_controller.dart';
import 'command_palette_dialog.dart';

class WorkspaceTopBar extends StatelessWidget {
  const WorkspaceTopBar({
    super.key,
    required this.currentRoute,
    required this.onStartStudySession,
    this.sessionController,
    this.breadcrumbs,
    this.onToggleSidebar,
    this.isSidebarCollapsed = false,
  });

  final AppRoute currentRoute;
  final VoidCallback onStartStudySession;
  final SessionController? sessionController;
  final List<String>? breadcrumbs;
  final VoidCallback? onToggleSidebar;
  final bool isSidebarCollapsed;

  String _getPageTitle() {
    switch (currentRoute) {
      case AppRoute.home:
        return 'Home';
      case AppRoute.study:
      case AppRoute.subjects:
        return 'Study Workspace';
      case AppRoute.notes:
        return 'Notes & Documents';
      case AppRoute.goals:
        return 'Goals & Milestones';
      case AppRoute.aiCoach:
        return 'Mentra AI';
      case AppRoute.focus:
        return 'Focus & CV Engine';
      case AppRoute.analytics:
        return 'Progress & Analytics';
      case AppRoute.settings:
        return 'Settings';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      child: Row(
        children: [
          // Mobile Hamburger / Sidebar Collapse Toggle
          if (onToggleSidebar != null) ...[
            IconButton(
              icon: Icon(
                isSidebarCollapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
                size: 20,
              ),
              color: theme.colorScheme.onSurfaceVariant,
              tooltip: isSidebarCollapsed ? 'Expand navigation' : 'Collapse navigation',
              onPressed: onToggleSidebar,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],

          // Breadcrumbs / Page Context
          Expanded(
            flex: isMobile ? 2 : 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMobile) ...[
                  Text(
                    'Workspace',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    breadcrumbs != null && breadcrumbs!.isNotEmpty
                        ? breadcrumbs!.join(' / ')
                        : _getPageTitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Center Search Trigger (Notion-style Cmd+K bar)
          if (!isMobile)
            Expanded(
              flex: 2,
              child: Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => CommandPaletteDialog.show(
                      context,
                      onStartStudySession: onStartStudySession,
                    ),
                    child: Container(
                      height: 34,
                      constraints: const BoxConstraints(maxWidth: 380),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF20201E) : const Color(0xFFF4F4F2),
                        borderRadius: AppRadius.borderSm,
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Search or jump to... (Cmd+K)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C28) : const Color(0xFFE8E8E4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '⌘K',
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
                  ),
                ),
              ),
            ),

          // Right Status & Profile Area
          Expanded(
            flex: isMobile ? 1 : 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Quick Search Icon for Mobile
                if (isMobile)
                  IconButton(
                    icon: const Icon(Icons.search_rounded, size: 20),
                    tooltip: 'Search workspace',
                    color: theme.colorScheme.onSurfaceVariant,
                    onPressed: () => CommandPaletteDialog.show(
                      context,
                      onStartStudySession: onStartStudySession,
                    ),
                  ),

                // Focus & CV Status Badge
                _buildFocusStatusIndicator(context, theme, isDark, isMobile),

                const SizedBox(width: AppSpacing.sm),

                // User Avatar
                Builder(
                  builder: (context) {
                    try {
                      final authCtrl = AuthScope.of(context);
                      final user = authCtrl.currentUser;
                      final name = user?.fullName?.trim() ?? 'Student';
                      final initial = name.isNotEmpty ? name[0].toUpperCase() : 'M';

                      return Tooltip(
                        message: user?.email ?? 'Logged in',
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D4036) : AppColors.primarySoft,
                            borderRadius: AppRadius.borderSm,
                            border: Border.all(
                              color: isDark ? const Color(0xFF3F5A4D) : const Color(0xFFBCD8CC),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      );
                    } catch (_) {
                      return const SizedBox.shrink();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusStatusIndicator(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    bool isMobile,
  ) {
    final controller = sessionController;
    final isActive = controller != null &&
        (controller.state == SessionState.active || controller.state == SessionState.paused);

    if (isActive) {
      final isPaused = controller.state == SessionState.paused;
      final score = controller.focusScore;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPaused
              ? (isDark ? const Color(0xFF332616) : AppColors.warningSubtle)
              : (isDark ? const Color(0xFF1B2E24) : AppColors.successSubtle),
          borderRadius: AppRadius.borderSm,
          border: Border.all(
            color: isPaused
                ? (isDark ? const Color(0xFF553E20) : const Color(0xFFF6DEC0))
                : (isDark ? const Color(0xFF284838) : const Color(0xFFC8E6D6)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isPaused ? AppColors.warning : AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isMobile
                  ? (isPaused ? 'Paused' : '$score%')
                  : (isPaused ? 'Session Paused' : 'Live Focus: $score%'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isPaused ? AppColors.warning : AppColors.success,
              ),
            ),
          ],
        ),
      );
    }

    // Idle state: Subtle CV Ready badge
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          NavigationScope.of(context).setRoute(AppRoute.focus);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF20201E) : const Color(0xFFF2F2F0),
            borderRadius: AppRadius.borderSm,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isMobile ? 'CV' : 'Focus Engine',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
