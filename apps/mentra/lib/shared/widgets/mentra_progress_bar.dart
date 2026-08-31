import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class MentraProgressBar extends StatelessWidget {
  const MentraProgressBar({
    super.key,
    required this.percentage,
    this.height = 6.0,
    this.color,
    this.showLabel = true,
  });

  final double percentage; // 0.0 to 1.0
  final double height;
  final Color? color;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedPercent = percentage.clamp(0.0, 1.0);
    final progressColor = color ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: AppTypography.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${(clampedPercent * 100).toInt()}%',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF2C2C2C)
                : AppColors.lightBorder,
            borderRadius: AppRadius.borderFull,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: clampedPercent,
            child: Container(
              decoration: BoxDecoration(
                color: progressColor,
                borderRadius: AppRadius.borderFull,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
