import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/core/theme/app_theme.dart';

void main() {
  group('AppTheme Tests', () {
    test('Light theme has correct primary colors', () {
      final theme = AppTheme.lightTheme;
      expect(theme.colorScheme.primary, equals(const Color(0xFF6366F1)));
      expect(theme.brightness, equals(Brightness.light));
    });

    test('Dark theme has correct primary colors', () {
      final theme = AppTheme.darkTheme;
      expect(theme.colorScheme.primary, equals(const Color(0xFF6366F1)));
      expect(theme.brightness, equals(Brightness.light));
    });
  });
}
