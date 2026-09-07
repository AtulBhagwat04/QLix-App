import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class DashboardHeader extends StatelessWidget {
  final String hostName;

  const DashboardHeader({
    super.key,
    required this.hostName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $hostName',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Ready to create engaging sessions?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFEEF2F6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.notifications_none_rounded,
                  size: 24,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No new notifications')),
                  );
                },
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: const Center(
                  child: Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
