import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/overview_stats.dart';

class OverviewStatsGrid extends StatelessWidget {
  final OverviewStats? stats;
  final List<Session> sessions;
  final VoidCallback onSessionsTap;

  const OverviewStatsGrid({
    super.key,
    required this.stats,
    required this.sessions,
    required this.onSessionsTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalSessions = stats?.totalSessions != null && stats!.totalSessions > 0
        ? stats!.totalSessions
        : sessions.length;

    final computedParticipants = sessions.fold<int>(
      0,
      (sum, s) => sum + s.participantCount,
    );
    final statsParticipants = stats?.totalParticipants ?? 0;
    final totalParticipants = statsParticipants > computedParticipants
        ? statsParticipants
        : computedParticipants;

    final totalResponses = stats?.totalResponses ?? 0;

    final computedQuizzes = sessions.fold<int>(
      0,
      (sum, s) => sum + s.pollCount,
    );
    final statsQuizzes = stats?.totalQuizzes ?? 0;
    final totalQuizzes =
        statsQuizzes > computedQuizzes ? statsQuizzes : computedQuizzes;

    void navigateToAnalytics() {
      if (sessions.isNotEmpty) {
        context.push('/analytics/${sessions.first.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No sessions available to view analytics'),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                letterSpacing: -0.5,
              ),
            ),
            TextButton(
              onPressed: navigateToAnalytics,
              child: const Row(
                children: [
                  Text(
                    'View Analytics',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _OverviewCard(
              value: '$totalSessions',
              label: 'Sessions',
              icon: Icons.forum_rounded,
              color: AppColors.primary,
              onTap: onSessionsTap,
            ),
            _OverviewCard(
              value: '$totalParticipants',
              label: 'Participants',
              icon: Icons.people_alt_rounded,
              color: AppColors.success,
              onTap: navigateToAnalytics,
            ),
            _OverviewCard(
              value: '$totalResponses',
              label: 'Responses',
              icon: Icons.chat_bubble_rounded,
              color: AppColors.warning,
              onTap: navigateToAnalytics,
            ),
            _OverviewCard(
              value: '$totalQuizzes',
              label: 'Quizzes',
              icon: Icons.bar_chart_rounded,
              color: AppColors.secondary,
              onTap: navigateToAnalytics,
            ),
          ],
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _OverviewCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark.withValues(alpha: 0.4)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 14,
                    color: isDark ? Colors.white30 : Colors.grey.shade400,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color:
                            isDark ? Colors.white : AppColors.textPrimaryLight,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
