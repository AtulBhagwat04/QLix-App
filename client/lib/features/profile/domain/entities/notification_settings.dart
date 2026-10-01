import 'package:equatable/equatable.dart';

class NotificationSettings extends Equatable {
  final bool pushEnabled;
  final bool sessionJoinedAlerts;
  final bool qaQuestionAlerts;
  final bool pollResponseAlerts;
  final bool weeklySummaryDigest;
  final bool platformAnnouncements;
  final String emailFrequency; // 'instant', 'daily', 'weekly', 'off'

  const NotificationSettings({
    this.pushEnabled = true,
    this.sessionJoinedAlerts = true,
    this.qaQuestionAlerts = true,
    this.pollResponseAlerts = false,
    this.weeklySummaryDigest = true,
    this.platformAnnouncements = true,
    this.emailFrequency = 'weekly',
  });

  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? sessionJoinedAlerts,
    bool? qaQuestionAlerts,
    bool? pollResponseAlerts,
    bool? weeklySummaryDigest,
    bool? platformAnnouncements,
    String? emailFrequency,
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      sessionJoinedAlerts: sessionJoinedAlerts ?? this.sessionJoinedAlerts,
      qaQuestionAlerts: qaQuestionAlerts ?? this.qaQuestionAlerts,
      pollResponseAlerts: pollResponseAlerts ?? this.pollResponseAlerts,
      weeklySummaryDigest: weeklySummaryDigest ?? this.weeklySummaryDigest,
      platformAnnouncements:
          platformAnnouncements ?? this.platformAnnouncements,
      emailFrequency: emailFrequency ?? this.emailFrequency,
    );
  }

  @override
  List<Object?> get props => [
        pushEnabled,
        sessionJoinedAlerts,
        qaQuestionAlerts,
        pollResponseAlerts,
        weeklySummaryDigest,
        platformAnnouncements,
        emailFrequency,
      ];
}
