import '../entities/user_profile.dart';
import '../entities/notification_settings.dart';

abstract class ProfileRepository {
  Future<UserProfile> getUserProfile();
  Future<UserProfile> updateUserProfile(UserProfile profile);
  Future<void> changePassword({required String newPassword});
  Future<NotificationSettings> getNotificationSettings();
  Future<NotificationSettings> updateNotificationSettings(
    NotificationSettings settings,
  );
}
