import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/blocs/auth_bloc.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/overview_stats.dart';

class DashboardProfileTab extends StatelessWidget {
  final String hostName;
  final String hostEmail;
  final OverviewStats? stats;
  final List<Session> sessions;
  final Future<void> Function() onRefresh;

  const DashboardProfileTab({
    super.key,
    required this.hostName,
    required this.hostEmail,
    required this.stats,
    required this.sessions,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = hostName.isNotEmpty
        ? hostName.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'A';

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

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFE8EAF6);
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSub =
        isDark ? const Color(0xFF94A3B8) : AppColors.textSecondaryLight;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Purple Profile Hero Card ────────────────────────────
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6366F1),
                    Color(0xFF564AE8),
                    Color(0xFF756CF5),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    right: -25,
                    top: -20,
                    child: IgnorePointer(
                      child: Text(
                        'Q',
                        style: TextStyle(
                          fontSize: 160,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withValues(alpha: 0.09),
                          fontFamily: 'sans-serif',
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  width: 3,
                                ),
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hostName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.4,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.mail_outline_rounded,
                                        size: 13,
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          hostEmail,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withValues(
                                              alpha: 0.85,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            _buildProfileStat(
                              icon: Icons.computer_rounded,
                              iconColor: const Color(0xFF8B5CF6),
                              value: '$totalSessions',
                              label: 'Sessions',
                              isDark: isDark,
                            ),
                            _buildStatDivider(isDark),
                            _buildProfileStat(
                              icon: Icons.people_outline_rounded,
                              iconColor: const Color(0xFF10B981),
                              value: '$totalParticipants',
                              label: 'Participants',
                              isDark: isDark,
                            ),
                            _buildStatDivider(isDark),
                            _buildProfileStat(
                              icon: Icons.poll_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              value: '$totalResponses',
                              label: 'Responses',
                              isDark: isDark,
                            ),
                            _buildStatDivider(isDark),
                            _buildProfileStat(
                              icon: Icons.question_answer,
                              iconColor: const Color(0xFF3B82F6),
                              value: '$totalQuizzes',
                              label: 'Quizzes',
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Account Section ─────────────────────────────────────
            _buildProfileSectionLabel('Account', textPrimary),
            const SizedBox(height: 10),
            _buildProfileGroup(
              isDark: isDark,
              cardBg: cardBg,
              cardBorder: cardBorder,
              items: [
                _buildProfileRow(
                  icon: Icons.person_outline_rounded,
                  title: 'Edit Profile',
                  subtitle: 'Update your personal information',
                  textPrimary: textPrimary,
                  textSub: textSub,
                  onTap: () {},
                  isFirst: true,
                  isLast: false,
                  isDark: isDark,
                ),
                _buildProfileRow(
                  icon: Icons.shield_outlined,
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  textPrimary: textPrimary,
                  textSub: textSub,
                  onTap: () {},
                  isFirst: false,
                  isLast: false,
                  isDark: isDark,
                ),
                _buildProfileRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle: 'Manage your notification preferences',
                  textPrimary: textPrimary,
                  textSub: textSub,
                  onTap: () {},
                  isFirst: false,
                  isLast: false,
                  isDark: isDark,
                ),
                _buildProfileRow(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Choose theme and app appearance',
                  textPrimary: textPrimary,
                  textSub: textSub,
                  onTap: () {},
                  isFirst: false,
                  isLast: true,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── General Section ─────────────────────────────────────
            _buildProfileSectionLabel('General', textPrimary),
            const SizedBox(height: 10),
            _buildProfileGroup(
              isDark: isDark,
              cardBg: cardBg,
              cardBorder: cardBorder,
              items: [
                _buildProfileRow(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  subtitle: 'Get help and view FAQs',
                  textPrimary: textPrimary,
                  textSub: textSub,
                  onTap: () {},
                  isFirst: true,
                  isLast: false,
                  isDark: isDark,
                ),
                _buildProfileRow(
                  icon: Icons.article_outlined,
                  title: 'Terms & Privacy',
                  subtitle: 'Read our terms and privacy policy',
                  textPrimary: textPrimary,
                  textSub: textSub,
                  onTap: () {},
                  isFirst: false,
                  isLast: false,
                  isDark: isDark,
                ),
                _buildProfileRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About Qlix',
                  subtitle: 'Version 1.0.0',
                  textPrimary: textPrimary,
                  textSub: textSub,
                  onTap: () {},
                  isFirst: false,
                  isLast: true,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Log Out Button ──────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    context.read<AuthBloc>().add(LogoutRequested());
                    context.go('/');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 20,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: AppColors.error,
                          size: 19,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── Version Footer ──────────────────────────────────────
            Center(
              child: Text(
                'QLix v1.0.0  •  Interactive Live Engagement',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white30 : Colors.grey.shade400,
                ),
              ),
            ),
          ],
        )
            .animate()
            .fade(duration: 400.ms)
            .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }

  Widget _buildProfileStat({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 38,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFF1F5F9),
    );
  }

  Widget _buildProfileSectionLabel(String label, Color textColor) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: textColor,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildProfileGroup({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: items),
    );
  }

  Widget _buildProfileRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textPrimary,
    required Color textSub,
    required VoidCallback onTap,
    required bool isFirst,
    required bool isLast,
    required bool isDark,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.vertical(
              top: isFirst ? const Radius.circular(16) : Radius.zero,
              bottom: isLast ? const Radius.circular(16) : Radius.zero,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: isDark ? Colors.white30 : Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            indent: 66,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFEEF2FF),
          ),
      ],
    );
  }
}
