import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class MentraAiAvatar extends StatelessWidget {
  const MentraAiAvatar({
    super.key,
    this.size = 36.0,
    this.isGenerating = false,
  });

  final double size;
  final bool isGenerating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isGenerating
            ? (isDark ? const Color(0xFF1B382E) : AppColors.primarySoft)
            : (isDark ? const Color(0xFF232321) : const Color(0xFFF2F2F0)),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: isGenerating
              ? (isDark ? AppColors.primaryDark : AppColors.primary)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.psychology_rounded,
          color: isGenerating
              ? (isDark ? AppColors.primaryDark : AppColors.primary)
              : theme.colorScheme.onSurface,
          size: size * 0.55,
        ),
      ),
    );
  }
}
