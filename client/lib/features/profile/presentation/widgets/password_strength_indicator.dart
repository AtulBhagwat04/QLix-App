import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  bool get hasMinLength => password.length >= 8;
  bool get hasUppercase => password.contains(RegExp(r'[A-Z]'));
  bool get hasNumberOrSpecial =>
      password.contains(RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]'));

  int get strengthScore {
    int score = 0;
    if (password.isNotEmpty) score++;
    if (hasMinLength) score++;
    if (hasUppercase) score++;
    if (hasNumberOrSpecial) score++;
    return score;
  }

  String get strengthLabel {
    if (password.isEmpty) return 'Enter a password';
    if (strengthScore <= 1) return 'Weak';
    if (strengthScore == 2) return 'Fair';
    if (strengthScore == 3) return 'Good';
    return 'Strong';
  }

  Color get strengthColor {
    if (password.isEmpty) return Colors.grey;
    if (strengthScore <= 1) return AppColors.error;
    if (strengthScore == 2) return AppColors.warning;
    if (strengthScore == 3) return const Color(0xFF3B82F6);
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password Strength',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondaryLight,
              ),
            ),
            Text(
              strengthLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: strengthColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(4, (index) {
            final active = index < strengthScore && password.isNotEmpty;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: active
                      ? strengthColor
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildCheckPill(
              label: '8+ characters',
              isMet: hasMinLength,
              isDark: isDark,
            ),
            _buildCheckPill(
              label: '1 uppercase letter',
              isMet: hasUppercase,
              isDark: isDark,
            ),
            _buildCheckPill(
              label: '1 number or symbol',
              isMet: hasNumberOrSpecial,
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckPill({
    required String label,
    required bool isMet,
    required bool isDark,
  }) {
    final activeColor = AppColors.success;
    final inactiveColor = isDark ? Colors.white30 : const Color(0xFF94A3B8);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isMet
            ? activeColor.withValues(alpha: 0.1)
            : (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMet
              ? activeColor.withValues(alpha: 0.35)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 13,
            color: isMet ? activeColor : inactiveColor,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isMet ? FontWeight.w700 : FontWeight.w500,
              color: isMet
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
