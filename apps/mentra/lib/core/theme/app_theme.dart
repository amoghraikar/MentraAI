import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

abstract class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primary,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      onSurfaceVariant: AppColors.lightTextSecondary,
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightBorderSubtle,
      surfaceContainerLowest: AppColors.lightCanvas,
      surfaceContainerLow: AppColors.lightSidebar,
      surfaceContainer: AppColors.lightCard,
      surfaceContainerHigh: AppColors.lightHover,
      error: AppColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightCanvas,
      dividerColor: AppColors.lightBorder,
      cardColor: AppColors.lightCard,
      textTheme: _buildTextTheme(AppColors.lightTextPrimary, AppColors.lightTextSecondary),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderLg,
          side: BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.lightTextMuted),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: AppColors.primaryDark,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySubtleDark,
      onPrimaryContainer: AppColors.primaryDark,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      onSurfaceVariant: AppColors.darkTextSecondary,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorderSubtle,
      surfaceContainerLowest: AppColors.darkCanvas,
      surfaceContainerLow: AppColors.darkSidebar,
      surfaceContainer: AppColors.darkCard,
      surfaceContainerHigh: AppColors.darkHover,
      error: AppColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkCanvas,
      dividerColor: AppColors.darkBorder,
      cardColor: AppColors.darkCard,
      textTheme: _buildTextTheme(AppColors.darkTextPrimary, AppColors.darkTextSecondary),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderLg,
          side: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextMuted),
      ),
    );
  }

  static TextTheme _buildTextTheme(Color primaryColor, Color secondaryColor) {
    return TextTheme(
      displayLarge: AppTypography.displayLarge.copyWith(
        color: primaryColor,
        fontFamilyFallback: AppTypography.fontFamilyFallback,
      ),
      displayMedium: AppTypography.displayMedium.copyWith(
        color: primaryColor,
        fontFamilyFallback: AppTypography.fontFamilyFallback,
      ),
      titleLarge: AppTypography.titleLarge.copyWith(
        color: primaryColor,
        fontFamilyFallback: AppTypography.fontFamilyFallback,
      ),
      titleMedium: AppTypography.titleMedium.copyWith(
        color: primaryColor,
        fontFamilyFallback: AppTypography.fontFamilyFallback,
      ),
      titleSmall: AppTypography.titleSmall.copyWith(
        color: primaryColor,
        fontFamilyFallback: AppTypography.fontFamilyFallback,
      ),
      bodyLarge: AppTypography.bodyLarge.copyWith(
        color: primaryColor,
        fontFamilyFallback: AppTypography.fontFamilyFallback,
      ),
      bodyMedium: AppTypography.bodyMedium.copyWith(
        color: secondaryColor,
        fontFamilyFallback: AppTypography.fontFamilyFallback,
      ),
      bodySmall: AppTypography.bodySmall.copyWith(
        color: secondaryColor,
        fontFamilyFallback: AppTypography.fontFamilyFallback,
      ),
      labelLarge: AppTypography.labelLarge.copyWith(
        color: primaryColor,
        fontFamilyFallback: AppTypography.fontFamilyFallback,
      ),
      labelMedium: AppTypography.labelMedium.copyWith(
        color: secondaryColor,
        fontFamilyFallback: AppTypography.fontFamilyFallback,
      ),
      labelSmall: AppTypography.labelSmall.copyWith(
        color: secondaryColor,
        fontFamilyFallback: AppTypography.fontFamilyFallback,
      ),
    );
  }
}
