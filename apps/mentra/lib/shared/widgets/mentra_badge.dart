import 'package:flutter/material.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

enum MentraBadgeVariant {
  neutral,
  primary,
  success,
  warning,
  danger,
}

class MentraBadge extends StatelessWidget {
  const MentraBadge({
    super.key,
    required this.label,
    this.variant = MentraBadgeVariant.neutral,
    this.icon,
  });

  final String label;
  final MentraBadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case MentraBadgeVariant.primary:
        bg = theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1);
        fg = theme.colorScheme.primary;
        border = theme.colorScheme.primary.withValues(alpha: 0.3);
        break;
      case MentraBadgeVariant.success:
        bg = const Color(0xFF16A34A).withValues(alpha: isDark ? 0.2 : 0.1);
        fg = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
        border = const Color(0xFF16A34A).withValues(alpha: 0.3);
        break;
      case MentraBadgeVariant.warning:
        bg = const Color(0xFFD97706).withValues(alpha: isDark ? 0.2 : 0.1);
        fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        border = const Color(0xFFD97706).withValues(alpha: 0.3);
        break;
      case MentraBadgeVariant.danger:
        bg = const Color(0xFFDC2626).withValues(alpha: isDark ? 0.2 : 0.1);
        fg = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
        border = const Color(0xFFDC2626).withValues(alpha: 0.3);
        break;
      case MentraBadgeVariant.neutral:
        bg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEC);
        fg = theme.colorScheme.onSurfaceVariant;
        border = theme.dividerColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
