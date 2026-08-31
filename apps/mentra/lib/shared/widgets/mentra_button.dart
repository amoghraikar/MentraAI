import 'package:flutter/material.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

enum MentraButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
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
            ? (isDark ? const Color(0xFF2563EB) : const Color(0xFF1D4ED8))
            : theme.colorScheme.primary;
        foregroundColor = Colors.white;
        border = null;
        break;
      case MentraButtonVariant.secondary:
        backgroundColor = _isHovered
            ? (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE8E8E6))
            : (isDark ? const Color(0xFF222222) : const Color(0xFFF0F0EE));
        foregroundColor = theme.colorScheme.onSurface;
        border = null;
        break;
      case MentraButtonVariant.outline:
        backgroundColor = _isHovered
            ? (isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F3))
            : Colors.transparent;
        foregroundColor = theme.colorScheme.onSurface;
        border = Border.all(
          color: _isHovered
              ? (isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC))
              : theme.dividerColor,
          width: 1,
        );
        break;
      case MentraButtonVariant.ghost:
        backgroundColor = _isHovered
            ? (isDark ? const Color(0xFF262626) : const Color(0xFFF2F2F0))
            : Colors.transparent;
        foregroundColor = theme.colorScheme.onSurfaceVariant;
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
