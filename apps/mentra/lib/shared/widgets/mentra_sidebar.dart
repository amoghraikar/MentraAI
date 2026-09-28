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

class MentraSidebar extends StatefulWidget {
  const MentraSidebar({
    super.key,
    this.onStartStudySession,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  final VoidCallback? onStartStudySession;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  @override
  State<MentraSidebar> createState() => _MentraSidebarState();
}

class _MentraSidebarState extends State<MentraSidebar> {
  late bool _collapsed;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.isCollapsed;
  }

  @override
  void didUpdateWidget(covariant MentraSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCollapsed != oldWidget.isCollapsed) {
      _collapsed = widget.isCollapsed;
    }
  }

  void _toggleCollapse() {
    setState(() {
      _collapsed = !_collapsed;
    });
    widget.onToggleCollapse?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final nav = NavigationScope.of(context);

    final workspaceRoutes = AppRoute.values.where((r) => r.group == NavGroup.workspace).toList();
    final insightsRoutes = AppRoute.values.where((r) => r.group == NavGroup.insights).toList();
    final systemRoutes = AppRoute.values.where((r) => r.group == NavGroup.system).toList();

    final width = _collapsed ? 68.0 : 248.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: width,
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
          // Header: Logo & Branding + Collapse Button
          Padding(
            padding: EdgeInsets.fromLTRB(
              _collapsed ? AppSpacing.sm : AppSpacing.md,
              AppSpacing.md,
              _collapsed ? AppSpacing.sm : AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment:
                  _collapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                if (!_collapsed)
                  Expanded(
                    child: Row(
                      children: [
                        const MentraBrandMark(size: 24),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'MENTRA',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const MentraBrandMark(size: 26),

                IconButton(
                  icon: Icon(
                    _collapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                    size: 18,
                  ),
                  color: theme.colorScheme.onSurfaceVariant,
                  tooltip: _collapsed ? 'Expand workspace sidebar' : 'Collapse sidebar',
                  onPressed: _toggleCollapse,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),

          // Primary Quick Action Button (Start Session)
          if (widget.onStartStudySession != null)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _collapsed ? AppSpacing.sm : AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: _collapsed
                  ? Tooltip(
                      message: 'Start Study Session',
                      child: MentraButton(
                        label: '',
                        icon: Icons.play_arrow_rounded,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        fullWidth: true,
                        onPressed: widget.onStartStudySession,
                      ),
                    )
                  : MentraButton(
                      label: 'Start Session',
                      icon: Icons.play_arrow_rounded,
                      fullWidth: true,
                      onPressed: widget.onStartStudySession,
                    ),
            ),

          const SizedBox(height: AppSpacing.xs),
          Divider(color: theme.dividerColor, height: 1),
          const SizedBox(height: AppSpacing.xs),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: _collapsed ? AppSpacing.xs : AppSpacing.sm,
              ),
              children: [
                if (!_collapsed) _buildGroupHeader('WORKSPACE', context),
                ...workspaceRoutes.map((route) => _SidebarNavItem(
                      route: route,
                      isActive: nav.currentRoute == route,
                      isCollapsed: _collapsed,
                      onTap: () => nav.setRoute(route),
                    )),
                const SizedBox(height: AppSpacing.sm),
                if (!_collapsed) _buildGroupHeader('INTELLIGENCE', context),
                ...insightsRoutes.map((route) => _SidebarNavItem(
                      route: route,
                      isActive: nav.currentRoute == route,
                      isCollapsed: _collapsed,
                      onTap: () => nav.setRoute(route),
                    )),
              ],
            ),
          ),

          // System Settings & Profile Footer
          Divider(color: theme.dividerColor, height: 1),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _collapsed ? AppSpacing.xs : AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: systemRoutes.map((route) => _SidebarNavItem(
                    route: route,
                    isActive: nav.currentRoute == route,
                    isCollapsed: _collapsed,
                    onTap: () => nav.setRoute(route),
                  )).toList(),
            ),
          ),

          // User Profile Card at Bottom
          _buildUserProfileFooter(context, theme, isDark, _collapsed),
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
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
        ),
      ),
    );
  }

  Widget _buildUserProfileFooter(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    bool isCollapsed,
  ) {
    try {
      final authCtrl = AuthScope.of(context);
      final user = authCtrl.currentUser;
      final fullName = user?.fullName;
      final userEmail = user?.email;
      final name = (fullName != null && fullName.trim().isNotEmpty)
          ? fullName.trim()
          : 'Alex Student';
      final email = (userEmail != null && userEmail.trim().isNotEmpty)
          ? userEmail.trim()
          : 'student@mentra.ai';
      final initials = name.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase();

      if (isCollapsed) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Center(
            child: Tooltip(
              message: '$name\n$email',
              child: GestureDetector(
                onTap: () => authCtrl.logout(),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: isDark ? const Color(0xFF2D4036) : AppColors.primarySoft,
                  child: Text(
                    initials.isNotEmpty ? initials : 'M',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF232321) : const Color(0xFFFFFFFF),
          borderRadius: AppRadius.borderSm,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: isDark ? const Color(0xFF2D4036) : AppColors.primarySoft,
              child: Text(
                initials.isNotEmpty ? initials : 'M',
                style: const TextStyle(
                  color: AppColors.primary,
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
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    email,
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sign Out',
              icon: const Icon(Icons.logout_rounded, size: 15),
              color: theme.colorScheme.onSurfaceVariant,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: () => authCtrl.logout(),
            ),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

class _SidebarNavItem extends StatefulWidget {
  const _SidebarNavItem({
    required this.route,
    required this.isActive,
    required this.isCollapsed,
    required this.onTap,
  });

  final AppRoute route;
  final bool isActive;
  final bool isCollapsed;
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
        ? (isDark ? const Color(0xFF262624) : AppColors.primarySoft.withValues(alpha: 0.6))
        : (_isHovered
            ? (isDark ? const Color(0xFF232321) : const Color(0xFFEFEFEA))
            : Colors.transparent);

    final Color fgColor = widget.isActive
        ? (isDark ? AppColors.primaryDark : AppColors.primary)
        : (_isHovered
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant);

    final itemWidget = Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCollapsed ? AppSpacing.sm : AppSpacing.sm + 2,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: AppRadius.borderSm,
            ),
            child: Row(
              mainAxisAlignment:
                  widget.isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  widget.isActive ? widget.route.activeIcon : widget.route.icon,
                  size: 17,
                  color: fgColor,
                ),
                if (!widget.isCollapsed) ...[
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Text(
                      widget.route.label,
                      style: AppTypography.bodySmall.copyWith(
                        color: fgColor,
                        fontSize: 13,
                        fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.isActive)
                    Container(
                      width: 3.5,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.primaryDark : AppColors.primary,
                        borderRadius: AppRadius.borderFull,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.isCollapsed) {
      return Tooltip(
        message: widget.route.label,
        child: itemWidget,
      );
    }

    return itemWidget;
  }
}
