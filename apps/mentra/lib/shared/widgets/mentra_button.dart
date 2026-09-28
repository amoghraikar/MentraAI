import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

enum MentraButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  danger,
}

class MentraButton extends StatefulWidget {
  const MentraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = MentraButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = false,
    this.padding,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final MentraButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final EdgeInsetsGeometry? padding;

  @override
  State<MentraButton> createState() => _MentraButtonState();
}

class _MentraButtonState extends State<MentraButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color backgroundColor;
    Color foregroundColor;
    Border? border;

    switch (widget.variant) {
      case MentraButtonVariant.primary:
        backgroundColor = _isHovered
            ? (isDark ? const Color(0xFF52A385) : AppColors.primaryHover)
            : (isDark ? AppColors.primaryDark : AppColors.primary);
        foregroundColor = isDark ? const Color(0xFF142420) : Colors.white;
        border = null;
        break;
      case MentraButtonVariant.secondary:
        backgroundColor = _isHovered
            ? (isDark ? const Color(0xFF292927) : const Color(0xFFEFEFEA))
            : (isDark ? const Color(0xFF232321) : const Color(0xFFFFFFFF));
        foregroundColor = theme.colorScheme.onSurface;
        border = Border.all(
          color: _isHovered
              ? (isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong)
              : theme.dividerColor,
          width: 1,
        );
        break;
      case MentraButtonVariant.outline:
        backgroundColor = _isHovered
            ? (isDark ? const Color(0xFF292927) : const Color(0xFFF7F7F5))
            : Colors.transparent;
        foregroundColor = theme.colorScheme.onSurface;
        border = Border.all(
          color: _isHovered
              ? (isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong)
              : theme.dividerColor,
          width: 1,
        );
        break;
      case MentraButtonVariant.ghost:
        backgroundColor = _isHovered
            ? (isDark ? const Color(0xFF292927) : const Color(0xFFEFEFEA))
            : Colors.transparent;
        foregroundColor = theme.colorScheme.onSurfaceVariant;
        border = null;
        break;
      case MentraButtonVariant.danger:
        backgroundColor = _isHovered ? const Color(0xFFBA3838) : AppColors.error;
        foregroundColor = Colors.white;
        border = null;
        break;
    }

    final buttonContent = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 16, color: foregroundColor),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelMedium.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    return MouseRegion(
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: widget.padding ??
              const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: 10,
              ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppRadius.borderMd,
            border: border,
          ),
          child: buttonContent,
        ),
      ),
    );
  }
}
