import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routing/app_route.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class MentraSidebar extends StatelessWidget {
  const MentraSidebar({super.key});

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
          // Subtle Wordmark & Branding Area
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.base,
              AppSpacing.lg,
              AppSpacing.base,
              AppSpacing.base,
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE8E8E6),
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: Center(
                    child: Text(
                      'M',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName.toUpperCase(),
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      AppConstants.appCategory,
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.2,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
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
