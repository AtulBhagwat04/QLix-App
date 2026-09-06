import 'package:flutter/material.dart';

/// Centralized design color tokens for QLix.
class AppColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFF6366F1); // Electric Indigo
  static const Color primaryLight = Color(0xFF818CF8); // Indigo 400
  static const Color primaryDark = Color(0xFF4F46E5); // Indigo 600
  static const Color primarySoft = Color(0xFFEEF2FF); // Indigo 50
  static const Color secondary = Color(0xFF06B6D4); // Ice Cyan
  static const Color accent = Color(0xFFF43F5E); // Sunset Rose
  static const Color purpleAccent = Color(0xFF8B5CF6); // Fuchsia Violet

  // Theme Surfaces & Backgrounds
  static const Color background = Color(0xFFF8F9FD); // Clean Off-white Ice
  static const Color backgroundLight = Color(0xFFF8F9FD);
  static const Color backgroundDark = Color(0xFFF8F9FD);
  static const Color surface = Colors.white;
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Colors.white;
  static const Color card = Colors.white;
  static const Color cardLight = Colors.white;
  static const Color cardDark = Colors.white;
  static const Color inputBackground = Color(0xFFF8FAFC); // Slate 50

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textPrimaryDark = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textSecondaryDark = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color textPlaceholder = Color(0xFF94A3B8); // Slate 400

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderLight = Color(0xFFEEF2FF); // Indigo 50 border
  static const Color divider = Color(0xFFE2E8F0);

  // Status & Utility Colors
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color successLight = Color(0xFFD1FAE5); // Emerald 100
  static const Color successDark = Color(0xFF059669); // Emerald 600

  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color errorLight = Color(0xFFFEE2E2); // Red 100
  static const Color errorDark = Color(0xFFDC2626); // Red 600

  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningLight = Color(0xFFFEF3C7); // Amber 100
  static const Color warningDark = Color(0xFFD97706); // Amber 600

  static const Color info = Color(0xFF3B82F6); // Blue 500
  static const Color infoLight = Color(0xFFDBEAFE); // Blue 100
  static const Color infoDark = Color(0xFF2563EB); // Blue 600

  // Shadows
  static Color shadowColor = Colors.black.withValues(alpha: 0.05);
  static Color primaryGlow = const Color(0xFF6366F1).withValues(alpha: 0.25);

  // Gradients
  static const List<Color> primaryGradient = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFF8B5CF6),
    Color(0xFF6366F1),
  ];

  static const List<Color> actionGradient = [
    Color(0xFF6366F1),
    Color(0xFF4F46E5),
  ];

  static const List<Color> bgGradient = [
    Color(0xFFF8F9FD),
    Color(0xFFEEF2FF),
  ];

  static const List<Color> tealGradient = [
    Color(0xFF06B6D4),
    Color(0xFF3B82F6),
  ];

  static const List<Color> accentGradient = [
    Color(0xFFF43F5E),
    Color(0xFFEC4899),
  ];

  static const List<Color> orangeGradient = [
    Color(0xFFF59E0B),
    Color(0xFFFBBF24),
  ];

  static const List<Color> greenGradient = [
    Color(0xFF10B981),
    Color(0xFF34D399),
  ];

  static const List<Color> splashLogoGradient = [
    Color(0xFFC084FC),
    Color(0xFF3B82F6),
    Color(0xFF06B6D4),
  ];
}
