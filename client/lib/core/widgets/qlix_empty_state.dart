import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import 'qlix_button.dart';

class QlixEmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? customIllustration;
  final Color? accentColor;
  final List<Color>? gradientColors;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final IconData? actionIcon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryActionPressed;
  final IconData? secondaryActionIcon;
  final bool compact;
  final List<String>? featurePills;
  final EdgeInsetsGeometry? padding;
  final double? maxContentWidth;

  const QlixEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.customIllustration,
    this.accentColor,
    this.gradientColors,
    this.actionLabel,
    this.onActionPressed,
    this.actionIcon,
    this.secondaryActionLabel,
    this.onSecondaryActionPressed,
    this.secondaryActionIcon,
    this.compact = false,
    this.featurePills,
    this.padding,
    this.maxContentWidth,
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Specialized Context Factories
  // ─────────────────────────────────────────────────────────────────────────────

  /// Empty state for when the host has no sessions created yet.
  factory QlixEmptyState.noSessions({
    Key? key,
    VoidCallback? onCreateSession,
    VoidCallback? onRefresh,
  }) {
    return QlixEmptyState(
      key: key,
      icon: Icons.rocket_launch_rounded,
      accentColor: AppColors.primary,
      gradientColors: AppColors.primaryGradient,
      title: 'Launch Your First Live Session',
      subtitle:
          'Create real-time polls, live Q&A streams, and competitive quizzes to engage your audience seamlessly.',
      actionLabel: 'Create Session',
      actionIcon: Icons.add_rounded,
      onActionPressed: onCreateSession,
      secondaryActionLabel: onRefresh != null ? 'Refresh' : null,
      secondaryActionIcon: Icons.refresh_rounded,
      onSecondaryActionPressed: onRefresh,
      featurePills: const [
        'Real-time Polls',
        'Live Audience Q&A',
        'Timed Quizzes',
        'Instant Analytics',
      ],
    );
  }

  /// Empty state for when a live session has no active polls yet.
  factory QlixEmptyState.noPolls({
    Key? key,
    VoidCallback? onCreatePoll,
    String? subtitle,
    bool compact = false,
  }) {
    return QlixEmptyState(
      key: key,
      compact: compact,
      icon: Icons.ballot_outlined,
      accentColor: const Color(0xFF6366F1),
      gradientColors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      title: 'No Active Polls',
      subtitle:
          subtitle ??
          'Create a multiple choice, word cloud, or rating poll to collect live audience responses in real time.',
      actionLabel: onCreatePoll != null ? 'Create First Poll' : null,
      actionIcon: Icons.add_chart_rounded,
      onActionPressed: onCreatePoll,
    );
  }

  /// Empty state for Q&A stream when no questions have been submitted.
  factory QlixEmptyState.noQuestions({
    Key? key,
    VoidCallback? onAskQuestion,
    String? subtitle,
    bool isHost = false,
    bool compact = false,
  }) {
    return QlixEmptyState(
      key: key,
      compact: compact,
      icon: Icons.forum_outlined,
      accentColor: const Color(0xFF06B6D4),
      gradientColors: const [Color(0xFF06B6D4), Color(0xFF3B82F6)],
      title: isHost ? 'Waiting for Audience Questions' : 'Be the First to Ask',
      subtitle:
          subtitle ??
          (isHost
              ? 'When participants submit questions using your session code, they will stream here live for moderation.'
              : 'Have a question or thought for the presenter? Type your question below to join the live discussion.'),
      actionLabel: onAskQuestion != null ? 'Ask Question' : null,
      actionIcon: Icons.send_rounded,
      onActionPressed: onAskQuestion,
    );
  }

  /// Empty state for Quiz competition tab when no quiz polls are added.
  factory QlixEmptyState.noQuizzes({
    Key? key,
    VoidCallback? onCreateQuiz,
    bool compact = false,
  }) {
    return QlixEmptyState(
      key: key,
      compact: compact,
      icon: Icons.emoji_events_outlined,
      accentColor: const Color(0xFFF59E0B),
      gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
      title: 'No Quiz Questions Yet',
      subtitle:
          'Gamify your presentation with timed, point-based challenge questions and live leaderboard rankings.',
      actionLabel: onCreateQuiz != null ? 'Add Quiz Question' : null,
      actionIcon: Icons.add_rounded,
      onActionPressed: onCreateQuiz,
    );
  }

  /// Empty state for Search and Filter views when no results are found.
  factory QlixEmptyState.noSearchResults({
    Key? key,
    required String query,
    VoidCallback? onClearSearch,
    bool compact = false,
  }) {
    return QlixEmptyState(
      key: key,
      compact: compact,
      icon: Icons.search_off_rounded,
      accentColor: const Color(0xFF8B5CF6),
      title: 'No Matches Found',
      subtitle: query.isNotEmpty
          ? 'We couldn\'t find anything matching "$query". Check for typos or try clearing your filters.'
          : 'No results match your selected criteria. Try adjusting your filter parameters.',
      actionLabel: onClearSearch != null ? 'Clear Search' : null,
      actionIcon: Icons.close_rounded,
      onActionPressed: onClearSearch,
    );
  }

  /// Empty state for Attendees/Participants list.
  factory QlixEmptyState.noAttendees({
    Key? key,
    VoidCallback? onShareCode,
    String? accessCode,
    bool compact = false,
  }) {
    return QlixEmptyState(
      key: key,
      compact: compact,
      icon: Icons.group_outlined,
      accentColor: const Color(0xFF10B981),
      gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
      title: 'No Participants Joined Yet',
      subtitle: accessCode != null && accessCode.isNotEmpty
          ? 'Share your session PIN ($accessCode) or QR code so attendees can join from their devices.'
          : 'Share your session PIN or QR code so attendees can join and participate in real time.',
      actionLabel: onShareCode != null ? 'Share Session' : null,
      actionIcon: Icons.share_rounded,
      onActionPressed: onShareCode,
    );
  }

  /// Empty state for Analytics activity timeline or charts.
  factory QlixEmptyState.noActivity({
    Key? key,
    String? title,
    String? message,
    bool compact = false,
  }) {
    return QlixEmptyState(
      key: key,
      compact: compact,
      icon: Icons.insights_rounded,
      accentColor: const Color(0xFF3B82F6),
      title: title ?? 'No Activity Data Yet',
      subtitle:
          message ??
          'Activity timelines, engagement velocity, and response statistics will generate as audience members interact.',
    );
  }

  /// Compact empty state for inline cards, small panels, or subordinate sections.
  factory QlixEmptyState.compact({
    Key? key,
    required String title,
    String? subtitle,
    IconData? icon,
    Color? accentColor,
    String? actionLabel,
    IconData? actionIcon,
    VoidCallback? onActionPressed,
    EdgeInsetsGeometry? padding,
  }) {
    return QlixEmptyState(
      key: key,
      compact: true,
      title: title,
      subtitle: subtitle,
      icon: icon,
      accentColor: accentColor,
      actionLabel: actionLabel,
      actionIcon: actionIcon,
      onActionPressed: onActionPressed,
      padding: padding,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build Methods
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = accentColor ?? AppColors.primary;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : AppColors.textSecondaryLight;

    if (compact) {
      return _buildCompactView(
        context,
        isDark,
        color,
        textPrimary,
        textSecondary,
      );
    }

    return _buildFullView(context, isDark, color, textPrimary, textSecondary);
  }

  Widget _buildCompactView(
    BuildContext context,
    bool isDark,
    Color color,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Center(
      child: Padding(
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth ?? 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Sleek mini icon container
              Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: isDark ? 0.16 : 0.10),
                      border: Border.all(
                        color: color.withValues(alpha: isDark ? 0.35 : 0.20),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        icon ?? Icons.inbox_outlined,
                        size: 26,
                        color: color,
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .scale(
                    begin: const Offset(0.85, 0.85),
                    end: const Offset(1, 1),
                  ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  letterSpacing: -0.2,
                ),
              ).animate().fadeIn(delay: 50.ms, duration: 350.ms),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: textSecondary,
                    height: 1.35,
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 350.ms),
              ],
              if (actionLabel != null && onActionPressed != null) ...[
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: onActionPressed,
                  icon: Icon(
                    actionIcon ?? Icons.arrow_forward_rounded,
                    size: 15,
                  ),
                  label: Text(actionLabel!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ).animate().fadeIn(delay: 150.ms, duration: 350.ms),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullView(
    BuildContext context,
    bool isDark,
    Color color,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth ?? 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing concentric hero orb
              if (customIllustration != null)
                customIllustration!
              else
                _buildHeroOrb(isDark, color),
              const SizedBox(height: 24),

              // Title
              Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.4,
                      height: 1.25,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),

              // Subtitle
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecondary,
                        height: 1.45,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 80.ms, duration: 400.ms)
                    .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
              ],

              // Feature Badges / Quick Highlights
              if (featurePills != null && featurePills!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: featurePills!.map((pill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : color.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusPill,
                            ),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : color.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            pill,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : color,
                            ),
                          ),
                        );
                      }).toList(),
                    )
                    .animate()
                    .fadeIn(delay: 140.ms, duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),
              ],

              // Actions
              if (actionLabel != null && onActionPressed != null) ...[
                const SizedBox(height: 32),
                QlixButton(
                      text: actionLabel!,
                      icon: actionIcon ?? Icons.add_rounded,
                      onPressed: onActionPressed,
                      gradientColors:
                          gradientColors ??
                          [color, color.withValues(alpha: 0.85)],
                      height: 48,
                      borderRadius: AppSizes.radiusPill,
                    )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms)
                    .scale(
                      begin: const Offset(0.92, 0.92),
                      end: const Offset(1, 1),
                    ),
              ],

              if (secondaryActionLabel != null &&
                  onSecondaryActionPressed != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onSecondaryActionPressed,
                  icon: Icon(
                    secondaryActionIcon ?? Icons.refresh_rounded,
                    size: 16,
                    color: color,
                  ),
                  label: Text(
                    secondaryActionLabel!,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ).animate().fadeIn(delay: 260.ms, duration: 400.ms),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroOrb(bool isDark, Color color) {
    return Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: isDark ? 0.28 : 0.16),
                color.withValues(alpha: isDark ? 0.08 : 0.04),
                Colors.transparent,
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? color.withValues(alpha: 0.18)
                    : color.withValues(alpha: 0.12),
                border: Border.all(
                  color: color.withValues(alpha: isDark ? 0.40 : 0.28),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: isDark ? 0.28 : 0.14),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon ?? Icons.inbox_rounded,
                  size: 36,
                  color: color,
                ),
              ),
            ),
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: -6, duration: 2200.ms, curve: Curves.easeInOut)
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.03, 1.03),
          duration: 2200.ms,
          curve: Curves.easeInOut,
        );
  }
}
