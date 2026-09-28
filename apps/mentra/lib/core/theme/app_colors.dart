import 'package:flutter/material.dart';

/// Semantic design colors for Mentra Workspace.
/// Notion-inspired calm, editorial palette with Mentra-native green identity.
abstract class AppColors {
  // Mentra Native Primary Palette (Section 7)
  static const Color primary = Color(0xFF2B6F5A);        // Mentra Green
  static const Color primaryHover = Color(0xFF245C4B);   // Primary Hover
  static const Color primarySoft = Color(0xFFE4F1EC);    // Primary Soft / Sage tint
  static const Color primaryDark = Color(0xFF65B99A);    // Mentra Accent for Dark Mode
  static const Color primarySubtle = Color(0xFFE4F1EC);
  static const Color primarySubtleDark = Color(0xFF1E2E28);

  // Brand Legacy Compatibility Aliases
  static const Color brandPine = Color(0xFF1F3D33);
  static const Color brandForest = Color(0xFF2B6F5A);
  static const Color brandSage = Color(0xFF65B99A);
  static const Color brandSteel = Color(0xFF8E9FA1);
  static const Color brandCream = Color(0xFFFBFBFA);

  // Status & Telemetry Accents
  static const Color success = Color(0xFF2E7D52);        // Semantic Success & Focused
  static const Color successSubtle = Color(0xFFEAF5EF);
  static const Color warning = Color(0xFFC47A19);        // Warning / Possible distraction
  static const Color warningSubtle = Color(0xFFFDF6EC);
  static const Color error = Color(0xFFD64545);          // Error / Distracted
  static const Color errorSubtle = Color(0xFFFDF0F0);
  static const Color info = Color(0xFF3B82F6);           // Informational Blue
  static const Color infoSubtle = Color(0xFFEFF6FF);

  // Special Feature Accents
  static const Color focusAccent = Color(0xFF2B6F5A);    // Focus state accent
  static const Color aiAccent = Color(0xFF5E5CE6);       // Subtle purple/indigo for AI
  static const Color aiAccentSubtle = Color(0xFFF1F0FD);
  static const Color aiAccentDark = Color(0xFF7A78FF);
  static const Color accent = Color(0xFF65B99A);
  static const Color accentSubtle = Color(0xFFE4F1EC);

  // Light Palette (Warm Notion Workspace)
  static const Color lightCanvas = Color(0xFFFBFBFA);    // Workspace background
  static const Color lightBackground = Color(0xFFFFFFFF);// Clean white base
  static const Color lightSurface = Color(0xFFF7F7F5);   // Surface background
  static const Color lightSidebar = Color(0xFFF7F7F5);   // Compact light sidebar
  static const Color lightCard = Color(0xFFFFFFFF);      // Card background
  static const Color lightBorder = Color(0xFFE6E4E0);    // Restrained 1px border
  static const Color lightBorderStrong = Color(0xFFD2D0CB);
  static const Color lightBorderSubtle = Color(0xFFEFEFEA);
  static const Color lightHover = Color(0xFFEFEFEA);     // Subtle hover state
  static const Color lightTextPrimary = Color(0xFF1F1F1D);// Warm off-black primary text
  static const Color lightTextSecondary = Color(0xFF6B6963);// Balanced secondary text
  static const Color lightTextMuted = Color(0xFF9B9891); // Muted metadata text

  // Dark Palette (Editorial Dark Workspace)
  static const Color darkCanvas = Color(0xFF191918);     // Dark background
  static const Color darkSurface = Color(0xFF232321);    // Dark surface
  static const Color darkElevated = Color(0xFF292927);   // Elevated panel
  static const Color darkSidebar = Color(0xFF1E1E1D);    // Compact dark sidebar
  static const Color darkCard = Color(0xFF232321);       // Dark card
  static const Color darkBorder = Color(0xFF373632);     // Subtle dark border
  static const Color darkBorderStrong = Color(0xFF484742);
  static const Color darkBorderSubtle = Color(0xFF2C2C29);
  static const Color darkHover = Color(0xFF292927);      // Subtle dark hover
  static const Color darkTextPrimary = Color(0xFFF5F5F3);// Off-white primary text
  static const Color darkTextSecondary = Color(0xFFA8A69F);// Secondary text
  static const Color darkTextMuted = Color(0xFF787670);  // Muted text

  // Convenient standard aliases
  static const Color border = lightBorder;
  static const Color borderStrong = lightBorderStrong;
  static const Color surface = lightSurface;
  static const Color surfaceHover = lightHover;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color textMuted = lightTextMuted;
  static const Color darkAccent = primaryDark;
  static const Color darkSurfaceElevated = darkElevated;
}
