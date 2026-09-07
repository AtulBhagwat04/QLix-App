import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class DashboardOfflineBanner extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const DashboardOfflineBanner({
    super.key,
    this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF2F2),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.redAccent.withValues(alpha: 0.3)
                : const Color(0xFFFCA5A5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Colors.redAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Server Offline Mode',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF991B1B),
                  ),
                ),
                Text(
                  message ??
                      'Unable to connect to server. Displaying offline data.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : const Color(0xFFB91C1C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text(
              'Retry',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
