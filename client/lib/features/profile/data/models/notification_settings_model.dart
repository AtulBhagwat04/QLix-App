import '../../domain/entities/notification_settings.dart';

class NotificationSettingsModel extends NotificationSettings {
  const NotificationSettingsModel({
    super.pushEnabled,
    super.sessionJoinedAlerts,
    super.qaQuestionAlerts,
    super.pollResponseAlerts,
    super.weeklySummaryDigest,
    super.platformAnnouncements,
    super.emailFrequency,
  });

  factory NotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    return NotificationSettingsModel(
      pushEnabled: json['pushEnabled'] as bool? ?? true,
      sessionJoinedAlerts: json['sessionJoinedAlerts'] as bool? ?? true,
      qaQuestionAlerts: json['qaQuestionAlerts'] as bool? ?? true,
      pollResponseAlerts: json['pollResponseAlerts'] as bool? ?? false,
      weeklySummaryDigest: json['weeklySummaryDigest'] as bool? ?? true,
      platformAnnouncements: json['platformAnnouncements'] as bool? ?? true,
      emailFrequency: json['emailFrequency'] as String? ?? 'weekly',
    );
  }

  factory NotificationSettingsModel.fromEntity(NotificationSettings entity) {
    return NotificationSettingsModel(
      pushEnabled: entity.pushEnabled,
      sessionJoinedAlerts: entity.sessionJoinedAlerts,
      qaQuestionAlerts: entity.qaQuestionAlerts,
      pollResponseAlerts: entity.pollResponseAlerts,
      weeklySummaryDigest: entity.weeklySummaryDigest,
      platformAnnouncements: entity.platformAnnouncements,
      emailFrequency: entity.emailFrequency,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pushEnabled': pushEnabled,
      'sessionJoinedAlerts': sessionJoinedAlerts,
      'qaQuestionAlerts': qaQuestionAlerts,
      'pollResponseAlerts': pollResponseAlerts,
      'weeklySummaryDigest': weeklySummaryDigest,
      'platformAnnouncements': platformAnnouncements,
      'emailFrequency': emailFrequency,
    };
  }
}
