import 'package:flutter/animation.dart';

/// Centralized animation durations and curves for QLix.
class AppDurations {
  static const Duration instant = Duration(milliseconds: 50);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration buttonPress = Duration(milliseconds: 100);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration medium = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration extraSlow = Duration(milliseconds: 800);
  static const Duration pageTransition = Duration(milliseconds: 350);
  static const Duration splashLoading = Duration(milliseconds: 2500);
  static const Duration splashLoop = Duration(milliseconds: 4000);
  static const Duration pulse = Duration(milliseconds: 1500);
}

/// Centralized animation curves.
class AppCurves {
  static const Curve standard = Curves.easeInOut;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;
  static const Curve bounce = Curves.easeOutBack;
  static const Curve smooth = Curves.easeInOutCubic;
  static const Curve decelerate = Curves.easeOutCubic;
}
