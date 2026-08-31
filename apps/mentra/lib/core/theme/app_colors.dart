import 'package:flutter/material.dart';

/// Semantic design colors for Mentra Workspace.
abstract class AppColors {
  // Brand Accent
  static const Color primary = Color(0xFF2563EB); // Deep modern blue
  static const Color primaryDark = Color(0xFF3B82F6);
  static const Color primarySubtle = Color(0xFFEFF6FF);
  static const Color primarySubtleDark = Color(0xFF1E293B);

  // Status & Telemetry Accents
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color successSubtle = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningSubtle = Color(0xFFFFFBEB);
  static const Color info = Color(0xFF6366F1); // Indigo
  static const Color infoSubtle = Color(0xFFEEF2FF);

  // Light Palette (Calm Notion-inspired workspace)
  static const Color lightCanvas = Color(0xFFFDFDFD);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSidebar = Color(0xFFF7F7F5);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFEBEBEA);
  static const Color lightBorderSubtle = Color(0xFFF2F2F0);
  static const Color lightHover = Color(0xFFF0F0EE);
  static const Color lightTextPrimary = Color(0xFF191919);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Dark Palette (Calm dark workstation)
  static const Color darkCanvas = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF181818);
  static const Color darkSidebar = Color(0xFF161616);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkBorder = Color(0xFF2A2A2A);
  static const Color darkBorderSubtle = Color(0xFF222222);
  static const Color darkHover = Color(0xFF262626);
  static const Color darkTextPrimary = Color(0xFFEDEDED);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);
}
