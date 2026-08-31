import 'package:flutter/material.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

class MentraCard extends StatefulWidget {
  const MentraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.base),
    this.onTap,
    this.isSelected = false,
    this.borderColor,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool isSelected;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  State<MentraCard> createState() => _MentraCardState();
}

class _MentraCardState extends State<MentraCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBorderColor = widget.isSelected
        ? theme.colorScheme.primary
        : (_isHovered
            ? (isDark ? const Color(0xFF3E3E3E) : const Color(0xFFD8D8D6))
            : theme.dividerColor);

    final defaultBgColor = widget.backgroundColor ??
        (widget.isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
            : (_isHovered
                ? theme.colorScheme.surfaceContainerHigh
                : theme.colorScheme.surfaceContainer));

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: defaultBgColor,
        borderRadius: AppRadius.borderMd,
        border: Border.all(
          color: widget.borderColor ?? defaultBorderColor,
          width: widget.isSelected ? 1.5 : 1.0,
        ),
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: content,
        ),
      );
    }

    return content;
  }
}
