import 'package:flutter/material.dart';
import '../../core/routing/app_route.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/auth/presentation/auth_controller.dart';
import 'mentra_button.dart';
import 'mentra_logo.dart';

class MentraSidebar extends StatelessWidget {
  const MentraSidebar({
    super.key,
    this.onStartStudySession,
  });

  final VoidCallback? onStartStudySession;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final nav = NavigationScope.of(context);

    final workspaceRoutes = AppRoute.values.where((r) => r.group == NavGroup.workspace).toList();
    final insightsRoutes = AppRoute.values.where((r) => r.group == NavGroup.insights).toList();
    final systemRoutes = AppRoute.values.where((r) => r.group == NavGroup.system).toList();

    return Container(
      width: AppSpacing.sidebarWidth,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSidebar : AppColors.lightSidebar,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Official Wordmark & Branding Area
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.base,
              AppSpacing.base,
              AppSpacing.base,
              AppSpacing.sm,
            ),
            child: const MentraLogo(
              markSize: 28,
              layout: MentraLogoLayout.horizontal,
              showTagline: true,
              taglineText: 'FOCUS  /  LEARN  /  GROW',
            ),
          ),

          // Primary Quick Action Button
          if (onStartStudySession != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.xs,
              ),
              child: MentraButton(
                label: 'Start Session',
                icon: Icons.play_arrow_rounded,
                fullWidth: true,
                onPressed: onStartStudySession,
              ),
            ),

          const SizedBox(height: AppSpacing.xs),
          Divider(color: theme.dividerColor, height: 1),
          const SizedBox(height: AppSpacing.sm),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              children: [
                _buildGroupHeader('WORKSPACE', context),
                ...workspaceRoutes.map((route) => _SidebarNavItem(
                      route: route,
                      isActive: nav.currentRoute == route,
                      onTap: () => nav.setRoute(route),
                    )),
                const SizedBox(height: AppSpacing.md),
                _buildGroupHeader('INSIGHTS', context),
                ...insightsRoutes.map((route) => _SidebarNavItem(
                      route: route,
                      isActive: nav.currentRoute == route,
                      onTap: () => nav.setRoute(route),
                    )),
              ],
            ),
          ),

          // Footer / System Settings
          Divider(color: theme.dividerColor, height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              children: systemRoutes.map((route) => _SidebarNavItem(
                    route: route,
                    isActive: nav.currentRoute == route,
                    onTap: () => nav.setRoute(route),
                  )).toList(),
            ),
          ),

          // User Profile & Quick Logout Footer
          Builder(
            builder: (context) {
              try {
                final authCtrl = AuthScope.of(context);
                final user = authCtrl.currentUser;
                final name = user?.fullName?.isNotEmpty == true ? user!.fullName! : 'Mentra Student';
                final email = user?.email.isNotEmpty == true ? user!.email : 'student@mentra.ai';
                final initials = name.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase();

                return Container(
                  margin: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141C18) : const Color(0xFFF0F5F2),
                    borderRadius: AppRadius.borderSm,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1F322B) : const Color(0xFFD9E7E0),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          initials.isNotEmpty ? initials : 'M',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Student: $name',
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              email,
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 9,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sign Out / Switch Account',
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        color: theme.colorScheme.onSurfaceVariant,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => authCtrl.logout(),
                      ),
                    ],
                  ),
                );
              } catch (_) {
                return const SizedBox.shrink();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title, BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Text(
        title,
        style: AppTypography.labelSmall.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  const _SidebarNavItem({
    required this.route,
    required this.isActive,
    required this.onTap,
  });

  final AppRoute route;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bgColor = widget.isActive
        ? (isDark ? const Color(0xFF262626) : const Color(0xFFEAEAEA))
        : (_isHovered
            ? (isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF0F0EE))
            : Colors.transparent);

    final Color fgColor = widget.isActive
        ? theme.colorScheme.onSurface
        : (_isHovered
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: AppRadius.borderSm,
            ),
            child: Row(
              children: [
                Icon(
                  widget.isActive ? widget.route.activeIcon : widget.route.icon,
                  size: 18,
                  color: widget.isActive ? theme.colorScheme.primary : fgColor,
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(
                    widget.route.label,
                    style: AppTypography.bodySmall.copyWith(
                      color: fgColor,
                      fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.isActive)
                  Container(
                    width: 4,
                    height: 14,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: AppRadius.borderFull,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
