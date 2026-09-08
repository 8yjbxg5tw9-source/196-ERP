import 'package:flutter/material.dart';

/// FinAI Studio enterprise design tokens.
///
/// The palette intentionally keeps the primary surfaces quiet so dense
/// accounting tables and positive/negative metrics remain easy to scan.
abstract final class AppColors {
  // Brand and semantic colors.
  static const Color primary = Color(0xFF0F172A); // Deep Slate Navy.
  static const Color primaryDark = Color(0xFF020617);
  static const Color accent = Color(0xFF059669); // Emerald Green.
  static const Color rose = Color(0xFFE11D48);
  static const Color amber = Color(0xFFD97706);

  // Semantic aliases used by the theme and feature widgets.
  static const Color success = accent;
  static const Color warning = amber;
  static const Color error = rose;

  // Light surfaces and borders.
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceMuted = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextMuted = Color(0xFF64748B);

  // Dark surfaces and borders.
  static const Color darkBackground = Color(0xFF090D16);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceMuted = Color(0xFF172033);
  static const Color darkBorder = Color(0xFF263247);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkTextMuted = Color(0xFF94A3B8);

  // Backwards-compatible aliases for core widgets created in Step 1.
  static const Color canvas = lightBackground;
  static const Color darkCanvas = darkBackground;
  static const Color ink = lightText;
  static const Color slate = lightTextMuted;
  static const Color secondary = accent;
}
