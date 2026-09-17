import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum MentraLogoVariant {
  /// Adapts to current theme (dark pine on light, crisp white on dark)
  adaptive,

  /// Dark pine + sage mint (for light backgrounds)
  dark,

  /// Crisp white + sage mint (for dark pine / dark backgrounds)
  light,

  /// Pure monochrome
  monochrome,
}

enum MentraLogoLayout {
  /// Mark + "Mentra" text + optional tagline side-by-side
  horizontal,

  /// Mark on top + "Mentra" text + tagline centered below
  stacked,

  /// Brand mark icon only
  markOnly,

  /// App icon in rounded container (squircle matching logo kit)
  appIcon,
}

/// Official Mentra Brand Mark (Open book & sprouting leaf geometry)
class MentraBrandMark extends StatelessWidget {
  const MentraBrandMark({
    super.key,
    this.size = 32.0,
    this.variant = MentraLogoVariant.adaptive,
    this.customLeafColor,
    this.customSproutColor,
  });

  final double size;
  final MentraLogoVariant variant;
  final Color? customLeafColor;
  final Color? customSproutColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color leafColor;
    Color sproutColor = customSproutColor ?? AppColors.brandSage;

    if (customLeafColor != null) {
      leafColor = customLeafColor!;
    } else {
      switch (variant) {
        case MentraLogoVariant.adaptive:
          leafColor = isDark ? Colors.white : AppColors.brandPine;
          break;
        case MentraLogoVariant.dark:
          leafColor = AppColors.brandPine;
          break;
        case MentraLogoVariant.light:
          leafColor = Colors.white;
          break;
        case MentraLogoVariant.monochrome:
          leafColor = isDark ? Colors.white : AppColors.brandPine;
          sproutColor = leafColor;
          break;
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MentraLogoPainter(
          leafColor: leafColor,
          sproutColor: sproutColor,
        ),
      ),
    );
  }
}

class _MentraLogoPainter extends CustomPainter {
  const _MentraLogoPainter({
    required this.leafColor,
    required this.sproutColor,
  });

  final Color leafColor;
  final Color sproutColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final leafPaint = Paint()
      ..color = leafColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final sproutPaint = Paint()
      ..color = sproutColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Left Leaf / Book Spine Page
    final leftPath = Path()
      ..moveTo(w * 0.12, h * 0.24)
      ..lineTo(w * 0.44, h * 0.14)
      ..lineTo(w * 0.44, h * 0.86)
      ..lineTo(w * 0.12, h * 0.74)
      ..close();
    canvas.drawPath(leftPath, leafPaint);

    // 2. Upper Right Sprout / Growth Leaf (Curved top-right leaf)
    final sproutPath = Path()
      ..moveTo(w * 0.56, h * 0.44)
      ..lineTo(w * 0.56, h * 0.24)
      ..quadraticBezierTo(w * 0.56, h * 0.12, w * 0.72, h * 0.12)
      ..quadraticBezierTo(w * 0.88, h * 0.16, w * 0.88, h * 0.36)
      ..close();
    canvas.drawPath(sproutPath, sproutPaint);

    // 3. Lower Right Leaf / Book Page
    final rightPath = Path()
      ..moveTo(w * 0.56, h * 0.52)
      ..lineTo(w * 0.88, h * 0.44)
      ..lineTo(w * 0.88, h * 0.72)
      ..lineTo(w * 0.56, h * 0.86)
      ..close();
    canvas.drawPath(rightPath, leafPaint);
  }

  @override
  bool shouldRepaint(covariant _MentraLogoPainter oldDelegate) =>
      oldDelegate.leafColor != leafColor || oldDelegate.sproutColor != sproutColor;
}

/// Complete Mentra Logo Lockup matching the official Logo Kit
class MentraLogo extends StatelessWidget {
  const MentraLogo({
    super.key,
    this.markSize = 28.0,
    this.layout = MentraLogoLayout.horizontal,
    this.variant = MentraLogoVariant.adaptive,
    this.showTagline = true,
    this.taglineText = 'FOCUS  /  LEARN  /  GROW',
    this.fontSize,
  });

  final double markSize;
  final MentraLogoLayout layout;
  final MentraLogoVariant variant;
  final bool showTagline;
  final String taglineText;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color textColor;
    switch (variant) {
      case MentraLogoVariant.adaptive:
        textColor = isDark ? Colors.white : AppColors.brandPine;
        break;
      case MentraLogoVariant.dark:
        textColor = AppColors.brandPine;
        break;
      case MentraLogoVariant.light:
        textColor = Colors.white;
        break;
      case MentraLogoVariant.monochrome:
        textColor = isDark ? Colors.white : AppColors.brandPine;
        break;
    }

    final computedFontSize = fontSize ?? (markSize * 0.82);

    if (layout == MentraLogoLayout.markOnly) {
      return MentraBrandMark(size: markSize, variant: variant);
    }

    if (layout == MentraLogoLayout.appIcon) {
      return Container(
        width: markSize * 1.5,
        height: markSize * 1.5,
        padding: EdgeInsets.all(markSize * 0.28),
        decoration: BoxDecoration(
          color: isDark ? AppColors.brandPine : AppColors.brandPine,
          borderRadius: BorderRadius.circular(markSize * 0.38),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: MentraBrandMark(
          size: markSize,
          variant: MentraLogoVariant.light,
        ),
      );
    }

    if (layout == MentraLogoLayout.stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MentraBrandMark(size: markSize, variant: variant),
          SizedBox(height: AppSpacing.sm),
          Text(
            AppConstants.appName,
            style: TextStyle(
              fontSize: computedFontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: textColor,
              height: 1.1,
            ),
          ),
          if (showTagline) ...[
            const SizedBox(height: 4),
            Text(
              taglineText,
              style: TextStyle(
                fontSize: (computedFontSize * 0.36).clamp(9.0, 13.0),
                fontWeight: FontWeight.w600,
                letterSpacing: 2.2,
                color: isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.brandPine.withValues(alpha: 0.65),
              ),
            ),
          ],
        ],
      );
    }

    // Horizontal layout
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MentraBrandMark(size: markSize, variant: variant),
          const SizedBox(width: AppSpacing.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: computedFontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: textColor,
                  height: 1.1,
                ),
              ),
              if (showTagline) ...[
                const SizedBox(height: 2),
                Text(
                  taglineText,
                  style: TextStyle(
                    fontSize: (computedFontSize * 0.36).clamp(8.0, 11.0),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                    color: isDark ? Colors.white.withValues(alpha: 0.55) : AppColors.brandPine.withValues(alpha: 0.65),
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
