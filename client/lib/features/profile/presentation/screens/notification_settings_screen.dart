import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/notification_settings.dart';
import '../blocs/profile_bloc.dart';
import '../blocs/profile_event.dart';
import '../blocs/profile_state.dart';
import '../widgets/profile_app_bar.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  void _updateSettings(
    BuildContext context,
    NotificationSettings current,
    NotificationSettings updated,
  ) {
    context.read<ProfileBloc>().add(
          UpdateNotificationSettingsRequested(updated),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSub = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondaryLight;

    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLoaded && state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(state.successMessage!),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, state) {
        NotificationSettings settings = const NotificationSettings();
        if (state is ProfileLoaded) {
          settings = state.notificationSettings;
        } else if (state is ProfileInitial) {
          context.read<ProfileBloc>().add(LoadProfile());
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FD),
          appBar: const ProfileAppBar(
            title: 'Notifications',
            subtitle: 'Manage alert preferences',
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Master Push Toggle Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Push Notifications',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Receive real-time alerts on your device',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: settings.pushEnabled,
                        thumbColor: const WidgetStatePropertyAll(Colors.white),
                        activeTrackColor: Colors.white.withValues(alpha: 0.4),
                        onChanged: (val) {
                          _updateSettings(
                            context,
                            settings,
                            settings.copyWith(pushEnabled: val),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Session Activity Section
                _buildSectionHeader('Live Session Alerts', textPrimary),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildSwitchRow(
                        icon: Icons.group_add_outlined,
                        title: 'Participant Joined',
                        subtitle: 'Notify when audience members join your session',
                        value: settings.sessionJoinedAlerts && settings.pushEnabled,
                        enabled: settings.pushEnabled,
                        isFirst: true,
                        isLast: false,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSub: textSub,
                        onChanged: (val) {
                          _updateSettings(
                            context,
                            settings,
                            settings.copyWith(sessionJoinedAlerts: val),
                          );
                        },
                      ),
                      _buildSwitchRow(
                        icon: Icons.question_answer_outlined,
                        title: 'New Q&A Question',
                        subtitle: 'Alert when a participant asks a new question',
                        value: settings.qaQuestionAlerts && settings.pushEnabled,
                        enabled: settings.pushEnabled,
                        isFirst: false,
                        isLast: false,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSub: textSub,
                        onChanged: (val) {
                          _updateSettings(
                            context,
                            settings,
                            settings.copyWith(qaQuestionAlerts: val),
                          );
                        },
                      ),
                      _buildSwitchRow(
                        icon: Icons.poll_outlined,
                        title: 'Live Poll Votes',
                        subtitle: 'Notify on poll and quiz responses in real-time',
                        value: settings.pollResponseAlerts && settings.pushEnabled,
                        enabled: settings.pushEnabled,
                        isFirst: false,
                        isLast: true,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSub: textSub,
                        onChanged: (val) {
                          _updateSettings(
                            context,
                            settings,
                            settings.copyWith(pollResponseAlerts: val),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Summaries & System
                _buildSectionHeader('Reports & Updates', textPrimary),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildSwitchRow(
                        icon: Icons.analytics_outlined,
                        title: 'Weekly Analytics Digest',
                        subtitle: 'Summary report of sessions and participant engagement',
                        value: settings.weeklySummaryDigest && settings.pushEnabled,
                        enabled: settings.pushEnabled,
                        isFirst: true,
                        isLast: false,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSub: textSub,
                        onChanged: (val) {
                          _updateSettings(
                            context,
                            settings,
                            settings.copyWith(weeklySummaryDigest: val),
                          );
                        },
                      ),
                      _buildSwitchRow(
                        icon: Icons.campaign_outlined,
                        title: 'Product Announcements',
                        subtitle: 'New features, release notes, and tips for hosts',
                        value: settings.platformAnnouncements && settings.pushEnabled,
                        enabled: settings.pushEnabled,
                        isFirst: false,
                        isLast: true,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSub: textSub,
                        onChanged: (val) {
                          _updateSettings(
                            context,
                            settings,
                            settings.copyWith(platformAnnouncements: val),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Email Frequency Card
                _buildSectionHeader('Email Digest Frequency', textPrimary),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildRadioOption(
                        label: 'Instant Alerts',
                        description: 'Receive an email as soon as an important event occurs',
                        value: 'instant',
                        groupValue: settings.emailFrequency,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSub: textSub,
                        onSelect: () {
                          _updateSettings(
                            context,
                            settings,
                            settings.copyWith(emailFrequency: 'instant'),
                          );
                        },
                      ),
                      const Divider(height: 16),
                      _buildRadioOption(
                        label: 'Daily Digest',
                        description: 'A single aggregated daily summary at 6:00 PM',
                        value: 'daily',
                        groupValue: settings.emailFrequency,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSub: textSub,
                        onSelect: () {
                          _updateSettings(
                            context,
                            settings,
                            settings.copyWith(emailFrequency: 'daily'),
                          );
                        },
                      ),
                      const Divider(height: 16),
                      _buildRadioOption(
                        label: 'Weekly Summary',
                        description: 'Weekly recap of host activity and engagement',
                        value: 'weekly',
                        groupValue: settings.emailFrequency,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSub: textSub,
                        onSelect: () {
                          _updateSettings(
                            context,
                            settings,
                            settings.copyWith(emailFrequency: 'weekly'),
                          );
                        },
                      ),
                      const Divider(height: 16),
                      _buildRadioOption(
                        label: 'Off',
                        description: 'Do not send email summaries',
                        value: 'off',
                        groupValue: settings.emailFrequency,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSub: textSub,
                        onSelect: () {
                          _updateSettings(
                            context,
                            settings,
                            settings.copyWith(emailFrequency: 'off'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fade(duration: 350.ms).slideY(begin: 0.03, end: 0),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required bool isFirst,
    required bool isLast,
    required bool isDark,
    required Color textPrimary,
    required Color textSub,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: enabled ? 0.09 : 0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: enabled ? AppColors.primary : Colors.grey,
                ),
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
                        color: enabled ? textPrimary : textSub,
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
              Switch.adaptive(
                value: value,
                activeTrackColor: AppColors.primary,
                onChanged: enabled ? onChanged : null,
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 66,
            color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
          ),
      ],
    );
  }

  Widget _buildRadioOption({
    required String label,
    required String description,
    required String value,
    required String groupValue,
    required bool isDark,
    required Color textPrimary,
    required Color textSub,
    required VoidCallback onSelect,
  }) {
    final isSelected = value == groupValue;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : (isDark ? Colors.white30 : const Color(0xFFCBD5E1)),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: textSub,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
