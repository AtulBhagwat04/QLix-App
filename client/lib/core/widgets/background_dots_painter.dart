import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reusable subtle decorative dots painter for backgrounds.
class BackgroundDotsPainter extends CustomPainter {
  final int seed;
  final int dotCount;
  final Color? dotColor;

  BackgroundDotsPainter({
    required this.seed,
    this.dotCount = 20,
    this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rand = math.Random(seed);
    final baseColor = dotColor ?? AppColors.primary;

    for (int i = 0; i < dotCount; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final radius = rand.nextDouble() * 2.0 + 0.5;
      final opacity = rand.nextDouble() * 0.08 + 0.02;

      paint.color = baseColor.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
