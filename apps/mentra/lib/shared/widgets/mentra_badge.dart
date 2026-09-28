import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
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
        bg = isDark ? const Color(0xFF1E2E28) : AppColors.primarySoft;
        fg = isDark ? AppColors.primaryDark : AppColors.primary;
        border = isDark ? const Color(0xFF2B4D40) : const Color(0xFFC7E2D7);
        break;
      case MentraBadgeVariant.success:
        bg = isDark ? const Color(0xFF1B2E24) : AppColors.successSubtle;
        fg = isDark ? const Color(0xFF65B99A) : AppColors.success;
        border = isDark ? const Color(0xFF284838) : const Color(0xFFC8E6D6);
        break;
      case MentraBadgeVariant.warning:
        bg = isDark ? const Color(0xFF332616) : AppColors.warningSubtle;
        fg = isDark ? const Color(0xFFFBBF24) : AppColors.warning;
        border = isDark ? const Color(0xFF553E20) : const Color(0xFFF6DEC0);
        break;
      case MentraBadgeVariant.danger:
        bg = isDark ? const Color(0xFF331C1C) : AppColors.errorSubtle;
        fg = isDark ? const Color(0xFFF87171) : AppColors.error;
        border = isDark ? const Color(0xFF5A2C2C) : const Color(0xFFF7C8C8);
        break;
      case MentraBadgeVariant.neutral:
        bg = isDark ? const Color(0xFF232321) : const Color(0xFFF2F2F0);
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
