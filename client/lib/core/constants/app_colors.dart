import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF6366F1);   // Electric Indigo
  static const Color secondary = Color(0xFF06B6D4); // Ice Teal
  static const Color accent = Color(0xFFF43F5E);    // Sunset Rose
  static const Color purpleAccent = Color(0xFF8B5CF6); // Fuchsia Violet

  // Theme Colors (Dark Cosmic Scheme -> Converted to Light everywhere)
  static const Color backgroundDark = Color(0xFFF5F7FB); // Clean Ice blue
  static const Color surfaceDark = Color(0xFFFFFFFF);    // Frosted light sheet
  static const Color cardDark = Color(0xFFFFFFFF);       // Solid light panel

  // Theme Colors (Light Ice Scheme)
  static const Color backgroundLight = Color(0xFFF5F7FB); // Clean Ice blue
  static const Color surfaceLight = Colors.white;
  static const Color cardLight = Colors.white;

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF0F172A); // Deep Slate
  static const Color textSecondaryLight = Color(0xFF475569); // Muted Slate
  static const Color textPrimaryDark = Color(0xFF0F172A);   // Deep Slate
  static const Color textSecondaryDark = Color(0xFF475569); // Muted Slate

  // Status & Utility Colors
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color error = Color(0xFFEF4444);   // Coral Red
  static const Color warning = Color(0xFFF59E0B); // Amber Gold
  static const Color info = Color(0xFF3B82F6);    // Blue

  // Gradients
  static const List<Color> bgGradient = [
    Color(0xFFF5F7FB),
    Color(0xFFE2E8F0), // Clean light ice tint
  ];

  static const List<Color> primaryGradient = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
  ];

  static const List<Color> tealGradient = [
    Color(0xFF06B6D4),
    Color(0xFF3B82F6),
  ];

  static const List<Color> accentGradient = [
    Color(0xFFF43F5E),
    Color(0xFFEC4899),
  ];
}

