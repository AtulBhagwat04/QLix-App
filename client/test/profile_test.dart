import 'package:client/features/profile/data/models/notification_settings_model.dart';
import 'package:client/features/profile/data/models/user_profile_model.dart';
import 'package:client/features/profile/domain/entities/notification_settings.dart';
import 'package:client/features/profile/domain/entities/user_profile.dart';
import 'package:client/features/profile/domain/repositories/profile_repository.dart';
import 'package:client/features/profile/presentation/blocs/profile_bloc.dart';
import 'package:client/features/profile/presentation/blocs/profile_event.dart';
import 'package:client/features/profile/presentation/blocs/profile_state.dart';
import 'package:client/features/profile/presentation/widgets/password_strength_indicator.dart';
import 'package:flutter_test/flutter_test.dart';

class MockProfileRepository implements ProfileRepository {
  UserProfile _profile = const UserProfile(
    id: 'test_user',
    fullName: 'Alex Johnson',
    email: 'alex@qlix.com',
    organization: 'QLix Interactive',
    headline: 'Lead Host',
    bio: 'Presenting live engagement sessions.',
  );

  NotificationSettings _settings = const NotificationSettings();

  @override
  Future<UserProfile> getUserProfile() async => _profile;

  @override
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    _profile = profile;
    return _profile;
  }

  @override
  Future<void> changePassword({required String newPassword}) async {
    if (newPassword.length < 6) throw Exception('Password too short');
  }

  @override
  Future<NotificationSettings> getNotificationSettings() async => _settings;

  @override
  Future<NotificationSettings> updateNotificationSettings(
    NotificationSettings settings,
  ) async {
    _settings = settings;
    return _settings;
  }
}

void main() {
  group('Profile Domain & Data Entities', () {
    test('UserProfileModel fromJson and toJson work correctly', () {
      final json = {
        'id': 'user_1',
        'fullName': 'John Doe',
        'email': 'john@example.com',
        'organization': 'Acme Corp',
        'headline': 'Instructor',
        'bio': 'Test bio',
        'avatarUrl': null,
      };

      final model = UserProfileModel.fromJson(json);
      expect(model.id, 'user_1');
      expect(model.fullName, 'John Doe');
      expect(model.email, 'john@example.com');
      expect(model.organization, 'Acme Corp');

      final serialized = model.toJson();
      expect(serialized['id'], 'user_1');
      expect(serialized['fullName'], 'John Doe');
    });

    test('NotificationSettings copyWith works properly', () {
      const settings = NotificationSettings();
      expect(settings.pushEnabled, true);

      final updated = settings.copyWith(pushEnabled: false, emailFrequency: 'daily');
      expect(updated.pushEnabled, false);
      expect(updated.emailFrequency, 'daily');
      expect(updated.sessionJoinedAlerts, true);
    });

    test('NotificationSettingsModel serializes correctly', () {
      const model = NotificationSettingsModel(
        pushEnabled: false,
        emailFrequency: 'instant',
      );
      final json = model.toJson();
      expect(json['pushEnabled'], false);
      expect(json['emailFrequency'], 'instant');

      final reconstructed = NotificationSettingsModel.fromJson(json);
      expect(reconstructed.pushEnabled, false);
      expect(reconstructed.emailFrequency, 'instant');
    });
  });

  group('PasswordStrengthIndicator Logic', () {
    test('Calculates score and labels correctly', () {
      const empty = PasswordStrengthIndicator(password: '');
      expect(empty.strengthScore, 0);
      expect(empty.strengthLabel, 'Enter a password');

      const weak = PasswordStrengthIndicator(password: 'abc');
      expect(weak.hasMinLength, false);
      expect(weak.strengthScore, 1);
      expect(weak.strengthLabel, 'Weak');

      const strong = PasswordStrengthIndicator(password: 'StrongP@ss1');
      expect(strong.hasMinLength, true);
      expect(strong.hasUppercase, true);
      expect(strong.hasNumberOrSpecial, true);
      expect(strong.strengthScore, 4);
      expect(strong.strengthLabel, 'Strong');
    });
  });

  group('ProfileBloc State Flow', () {
    late MockProfileRepository mockRepository;
    late ProfileBloc bloc;

    setUp(() {
      mockRepository = MockProfileRepository();
      bloc = ProfileBloc(mockRepository);
    });

    tearDown(() {
      bloc.close();
    });

    test('LoadProfile loads user profile and emits ProfileLoaded', () async {
      expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ProfileLoading>(),
          isA<ProfileLoaded>().having(
            (s) => s.profile.fullName,
            'fullName',
            'Alex Johnson',
          ),
        ]),
      );

      bloc.add(LoadProfile());
    });

    test('UpdateProfileRequested updates profile in state', () async {
      bloc.add(LoadProfile());
      await bloc.stream.firstWhere((s) => s is ProfileLoaded);

      final updatedProfile = (bloc.state as ProfileLoaded).profile.copyWith(
            fullName: 'Alex Smith',
          );

      bloc.add(UpdateProfileRequested(updatedProfile));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ProfileLoaded>().having((s) => s.isSaving, 'isSaving', true),
          isA<ProfileLoaded>()
              .having((s) => s.profile.fullName, 'fullName', 'Alex Smith')
              .having((s) => s.successMessage, 'successMessage', isNotNull),
        ]),
      );
    });
  });
}
