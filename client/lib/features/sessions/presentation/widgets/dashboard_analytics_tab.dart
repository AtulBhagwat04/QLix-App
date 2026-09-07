import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/overview_stats.dart';

class DashboardAnalyticsTab extends StatelessWidget {
  final OverviewStats? stats;
  final List<Session> sessions;
  final Future<void> Function() onRefresh;

  const DashboardAnalyticsTab({
    super.key,
    required this.stats,
    required this.sessions,
    required this.onRefresh,
  });

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Recently';
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

    final liveCount = sessions.where((s) => s.isLive).length;
    final draftCount = sessions.where((s) => s.isDraft).length;
    final endedCount = sessions.where((s) => s.isEnded).length;

    final avgAttendance =
        totalSessions > 0 ? (totalParticipants / totalSessions) : 0.0;
    final healthScore = totalSessions == 0
        ? 0
        : ((avgAttendance * 12 + totalResponses * 2).clamp(40, 98)).toInt();

    final sortedSessions = List<Session>.from(sessions)
      ..sort((a, b) {
        if (b.participantCount != a.participantCount) {
          return b.participantCount.compareTo(a.participantCount);
        }
        if (b.pollCount != a.pollCount) {
          return b.pollCount.compareTo(a.pollCount);
        }
        final dateA = DateTime.tryParse(a.createdAt ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b.createdAt ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
    final topSessions = sortedSessions.take(5).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analytics & Insights',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color:
                            isDark ? Colors.white : AppColors.textPrimaryLight,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Audience performance intelligence',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white54
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'All Time',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildAnalyticsHeroCard(
              isDark: isDark,
              healthScore: healthScore,
              totalSessions: totalSessions,
              totalParticipants: totalParticipants,
              totalResponses: totalResponses,
              avgAttendance: avgAttendance,
              liveCount: liveCount,
            ),
            const SizedBox(height: 22),
            _buildLifecycleDistributionSection(
              isDark: isDark,
              totalSessions: totalSessions,
              liveCount: liveCount,
              draftCount: draftCount,
              endedCount: endedCount,
            ),
            const SizedBox(height: 22),
            _buildFeatureActivitySection(
              isDark: isDark,
              totalResponses: totalResponses,
              totalQuizzes: totalQuizzes,
              totalParticipants: totalParticipants,
            ),
            const SizedBox(height: 24),
            _buildTopSessionsLeaderboard(
              context: context,
              isDark: isDark,
              topSessions: topSessions,
            ),
          ],
        )
            .animate()
            .fade(duration: 400.ms)
            .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }

  Widget _buildAnalyticsHeroCard({
    required bool isDark,
    required int healthScore,
    required int totalSessions,
    required int totalParticipants,
    required int totalResponses,
    required double avgAttendance,
    required int liveCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
              : [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34D399),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            totalSessions == 0
                                ? 'READY TO ENGAGE'
                                : 'HIGH IMPACT HOST',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFA5B4FC),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$totalParticipants',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.0,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Audience Members Reached',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 68,
                      height: 68,
                      child: CircularProgressIndicator(
                        value: totalSessions == 0
                            ? 0.05
                            : (healthScore / 100.0),
                        strokeWidth: 6.5,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF34D399),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$healthScore%',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'Score',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildHeroStatItem(
                    label: 'Avg / Session',
                    value: avgAttendance.toStringAsFixed(1),
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                Expanded(
                  child: _buildHeroStatItem(
                    label: 'Responses',
                    value: '$totalResponses',
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                Expanded(
                  child: _buildHeroStatItem(
                    label: 'Live Now',
                    value: '$liveCount',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatItem({required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFFA5B4FC),
          ),
        ),
      ],
    );
  }

  Widget _buildLifecycleDistributionSection({
    required bool isDark,
    required int totalSessions,
    required int liveCount,
    required int draftCount,
    required int endedCount,
  }) {
    final liveRatio = totalSessions > 0 ? (liveCount / totalSessions) : 0.0;
    final draftRatio = totalSessions > 0 ? (draftCount / totalSessions) : 0.0;
    final endedRatio = totalSessions > 0
        ? (endedCount / totalSessions)
        : (totalSessions == 0 ? 1.0 : 0.0);

    return Container(
      padding: const EdgeInsets.all(16),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Session Distribution',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              Text(
                '$totalSessions total',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (liveRatio > 0)
                    Expanded(
                      flex: (liveRatio * 100).toInt(),
                      child: Container(color: AppColors.success),
                    ),
                  if (draftRatio > 0)
                    Expanded(
                      flex: (draftRatio * 100).toInt(),
                      child: Container(color: AppColors.primary),
                    ),
                  if (endedRatio > 0)
                    Expanded(
                      flex: (endedRatio * 100).toInt(),
                      child: Container(
                        color: isDark
                            ? const Color(0xFF475569)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendChip(
                dotColor: AppColors.success,
                label: 'Live',
                count: liveCount,
                isDark: isDark,
              ),
              _buildLegendChip(
                dotColor: AppColors.primary,
                label: 'Draft',
                count: draftCount,
                isDark: isDark,
              ),
              _buildLegendChip(
                dotColor: isDark
                    ? const Color(0xFF475569)
                    : const Color(0xFF94A3B8),
                label: 'Ended',
                count: endedCount,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendChip({
    required Color dotColor,
    required String label,
    required int count,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureActivitySection({
    required bool isDark,
    required int totalResponses,
    required int totalQuizzes,
    required int totalParticipants,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interaction Breakdown',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.poll_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'Polls Activity',
                countText: '$totalResponses votes',
                subtitle: 'Audience polling',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.emoji_events_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Quiz Game',
                countText: '$totalQuizzes active',
                subtitle: 'Leaderboards',
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String countText,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.4)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            countText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSessionsLeaderboard({
    required BuildContext context,
    required bool isDark,
    required List<Session> topSessions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Top Performing Sessions',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            if (topSessions.isNotEmpty)
              Text(
                'By Attendees',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (topSessions.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceDark.withValues(alpha: 0.4)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.leaderboard_outlined,
                    size: 36,
                    color: Colors.grey.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No session activity yet',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...topSessions.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            final id = s.id;
            final title = s.displayTitle;
            final participants = s.participantCount;
            final dateStr = _formatDate(s.createdAt);

            Color rankBg;
            Color rankFg;
            if (idx == 0) {
              rankBg = const Color(0xFFFEF3C7);
              rankFg = const Color(0xFFD97706);
            } else if (idx == 1) {
              rankBg = const Color(0xFFF1F5F9);
              rankFg = const Color(0xFF475569);
            } else if (idx == 2) {
              rankBg = const Color(0xFFFFEDD5);
              rankFg = const Color(0xFFC2410C);
            } else {
              rankBg = isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF8FAFC);
              rankFg = Colors.grey;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark.withValues(alpha: 0.4)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: () => context.push('/analytics/$id'),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: rankBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: rankFg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white38 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.people_alt_rounded,
                              size: 12,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$participants',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: isDark ? Colors.white30 : Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
