import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'mentra_badge.dart';
import 'mentra_card.dart';

class MentraStatCard extends StatelessWidget {
  const MentraStatCard({
    super.key,
    String? label,
    String? title,
    required this.value,
    String? subvalue,
    String? subtitle,
    this.icon,
    this.iconColor,
    this.trendLabel,
  })  : label = label ?? title ?? '',
        subvalue = subvalue ?? subtitle;

  final String label;
  final String value;
  final String? subvalue;
  final IconData? icon;
  final Color? iconColor;
  final String? trendLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MentraCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (trendLabel != null)
                MentraBadge(label: trendLabel!, variant: MentraBadgeVariant.success)
              else if (icon != null)
                Icon(
                  icon,
                  size: 16,
                  color: iconColor ?? theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (subvalue != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    subvalue!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
