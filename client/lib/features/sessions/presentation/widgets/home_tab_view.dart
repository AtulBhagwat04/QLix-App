import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/overview_stats.dart';
import 'dashboard_header.dart';
import 'quick_actions_bar.dart';
import 'overview_stats_grid.dart';
import 'session_card_tile.dart';
import 'session_menu_sheet.dart';

class HomeTabView extends StatelessWidget {
  final String hostName;
  final OverviewStats? stats;
  final List<Session> sessions;
  final Future<void> Function() onRefresh;
  final VoidCallback onViewAllSessions;

  const HomeTabView({
    super.key,
    required this.hostName,
    required this.stats,
    required this.sessions,
    required this.onRefresh,
    required this.onViewAllSessions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recentSessions = sessions.take(5).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DashboardHeader(hostName: hostName),
            const SizedBox(height: 16),
            const QuickActionsBar(),
            const SizedBox(height: 20),
            OverviewStatsGrid(
              stats: stats,
              sessions: sessions,
              onSessionsTap: onViewAllSessions,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Sessions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    letterSpacing: -0.5,
                  ),
                ),
                if (sessions.isNotEmpty)
                  TextButton(
                    onPressed: onViewAllSessions,
                    child: const Text(
                      'View All',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (recentSessions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        size: 44,
                        color: Colors.grey.withValues(alpha: 0.35),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No sessions yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
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
                  children: recentSessions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final session = entry.value;
                    return SessionCardTile(
                      session: session,
                      index: idx,
                      totalCount: recentSessions.length,
                      onTap: () => context.push('/analytics/${session.id}'),
                      onMenuTap: () => SessionMenuSheet.show(context, session),
                    );
                  }).toList(),
                ),
              ),
          ],
        )
            .animate()
            .fade(duration: 400.ms)
            .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }
}
