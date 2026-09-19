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
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isGenerating
              ? [
                  AppColors.primary,
                  AppColors.accent,
                ]
              : [
                  isDark ? const Color(0xFF2A2A2A) : const Color(0xFF1E293B),
                  isDark ? const Color(0xFF181818) : const Color(0xFF0F172A),
                ],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: isGenerating
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          Icons.psychology_rounded,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}
