import 'package:flutter/material.dart';

/// Semantic design colors for Mentra Workspace.
abstract class AppColors {
  // Official Brand Kit Colors
  static const Color brandPine = Color(0xFF173029);    // Deep forest pine (Primary wordmark & base)
  static const Color brandForest = Color(0xFF2E5E4E);  // Medium rich forest green
  static const Color brandSage = Color(0xFF8EB89B);    // Sage mint (Sprout & growth accent)
  static const Color brandSteel = Color(0xFF8E9FA1);   // Slate steel neutral
  static const Color brandCream = Color(0xFFF6F8F6);   // Soft mist canvas

  // Brand Accent Semantic Tokens
  static const Color primary = Color(0xFF235344);      // Deep forest green primary
  static const Color primaryDark = Color(0xFF4A8572);  // Lighter forest for dark mode
  static const Color primarySubtle = Color(0xFFEDF5F1);// Soft sage wash
  static const Color primarySubtleDark = Color(0xFF162823);

  // Secondary / Feature Accents
  static const Color accent = Color(0xFF8EB89B);       // Sage mint
  static const Color accentSubtle = Color(0xFFF1F8F4);

  // Status & Telemetry Accents
  static const Color success = Color(0xFF2E8B57);      // Sea Green
  static const Color successSubtle = Color(0xFFEDF7F2);
  static const Color warning = Color(0xFFE58E26);      // Amber
  static const Color warningSubtle = Color(0xFFFFF7ED);
  static const Color error = Color(0xFFD94848);        // Coral Red
  static const Color errorSubtle = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF3B82F6);         // Blue
  static const Color infoSubtle = Color(0xFFEFF6FF);

  // Light Palette (Calm Notion-inspired workspace with pine & sage accents)
  static const Color lightCanvas = Color(0xFFF8FAF8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSidebar = Color(0xFFF2F5F3);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE4EAE6);
  static const Color lightBorderSubtle = Color(0xFFEEF3F0);
  static const Color lightHover = Color(0xFFEBF1EE);
  static const Color lightTextPrimary = Color(0xFF173029);
  static const Color lightTextSecondary = Color(0xFF5A7069);
  static const Color lightTextMuted = Color(0xFF8E9FA1);

  // Dark Palette (Calm dark workstation with pine & sage accents)
  static const Color darkCanvas = Color(0xFF0F1A17);
  static const Color darkSurface = Color(0xFF142420);
  static const Color darkSidebar = Color(0xFF121F1B);
  static const Color darkCard = Color(0xFF192B26);
  static const Color darkBorder = Color(0xFF223832);
  static const Color darkBorderSubtle = Color(0xFF1B2E29);
  static const Color darkHover = Color(0xFF1F332D);
  static const Color darkTextPrimary = Color(0xFFF1F5F3);
  static const Color darkTextSecondary = Color(0xFF9AB2A8);
  static const Color darkTextMuted = Color(0xFF6E867D);
}
