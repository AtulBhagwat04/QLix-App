import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/session.dart';

class SessionCardTile extends StatelessWidget {
  final Session session;
  final int index;
  final int totalCount;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  const SessionCardTile({
    super.key,
    required this.session,
    required this.index,
    required this.totalCount,
    required this.onTap,
    required this.onMenuTap,
  });

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLive = session.isLive;

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: index == 0 ? const Radius.circular(16) : Radius.zero,
          bottom:
              index == totalCount - 1 ? const Radius.circular(16) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isLive
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : AppColors.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isLive ? Icons.sensors_rounded : Icons.forum_rounded,
                  color: isLive
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color:
                            isDark ? Colors.white : AppColors.textPrimaryLight,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 11,
                            color:
                                isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(session.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '•',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.people_outline_rounded,
                            size: 13,
                            color:
                                isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${session.participantCount}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                  size: 20,
                ),
                onPressed: onMenuTap,
              ),
            ],
          ),
        ),
      ),
    );

    if (index < totalCount - 1) {
      return Column(
        children: [
          tile,
          Divider(
            height: 1,
            thickness: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF1F5F9),
          ),
        ],
      );
    }
    return tile;
  }
}
