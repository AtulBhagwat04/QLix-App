import 'dart:convert';
import '../../../../core/storage/cache_manager.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../models/notification_settings_model.dart';
import '../models/user_profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final SecureStorageService _secureStorage;
  final CacheManager _cacheManager;

  ProfileRepositoryImpl(
    this._secureStorage,
    this._cacheManager,
  );

  @override
  Future<UserProfile> getUserProfile() async {
    // 1. Check local cached profile first
    final cached = _cacheManager.getUserProfile();
    if (cached != null) {
      return UserProfileModel.fromJson(cached);
    }

    // 2. Decode from JWT token
    try {
      final token = await _secureStorage.getAccessToken();
      if (token != null) {
        final payload = _decodeJwt(token);
        final profile = UserProfile(
          id: payload['id'] as String? ?? payload['userId'] as String? ?? 'host_user',
          fullName: payload['name'] as String? ?? 'Alex Johnson',
          email: payload['email'] as String? ?? 'alex@qlix.com',
          organization: 'QLix Interactive',
          headline: 'Live Session Host & Presenter',
          bio: 'Engaging live audiences with real-time interactive polls, quizzes, and Q&A sessions.',
        );
        await _cacheManager.saveUserProfile(
          UserProfileModel.fromEntity(profile).toJson(),
        );
        return profile;
      }
    } catch (_) {
      // Fallback below
    }

    return const UserProfile(
      id: 'default_user',
      fullName: 'Alex Johnson',
      email: 'alex@qlix.com',
      organization: 'QLix Interactive',
      headline: 'Live Session Host & Presenter',
      bio: 'Engaging live audiences with real-time interactive polls, quizzes, and Q&A sessions.',
    );
  }

  @override
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    // Save to cache
    final model = UserProfileModel.fromEntity(profile);
    await _cacheManager.saveUserProfile(model.toJson());
    return profile;
  }

  @override
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    // Simulate slight network duration for realistic UX feedback
    await Future.delayed(const Duration(milliseconds: 600));

    if (newPassword.length < 6) {
      throw Exception('New password must be at least 6 characters.');
    }
  }

  @override
  Future<NotificationSettings> getNotificationSettings() async {
    final cached = _cacheManager.getNotificationSettings();
    if (cached != null) {
      return NotificationSettingsModel.fromJson(cached);
    }
    const defaultSettings = NotificationSettings();
    await _cacheManager.saveNotificationSettings(
      NotificationSettingsModel.fromEntity(defaultSettings).toJson(),
    );
    return defaultSettings;
  }

  @override
  Future<NotificationSettings> updateNotificationSettings(
    NotificationSettings settings,
  ) async {
    final model = NotificationSettingsModel.fromEntity(settings);
    await _cacheManager.saveNotificationSettings(model.toJson());
    return settings;
  }

  Map<String, dynamic> _decodeJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid token');
    }
    final payload = parts[1];
    var normalized = base64Url.normalize(payload);
    final resp = utf8.decode(base64Url.decode(normalized));
    return json.decode(resp) as Map<String, dynamic>;
  }
}
