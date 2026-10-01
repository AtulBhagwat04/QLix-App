import 'package:equatable/equatable.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/entities/user_profile.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadProfile extends ProfileEvent {}

class UpdateProfileRequested extends ProfileEvent {
  final UserProfile profile;

  const UpdateProfileRequested(this.profile);

  @override
  List<Object?> get props => [profile];
}

class ChangePasswordRequested extends ProfileEvent {
  final String newPassword;

  const ChangePasswordRequested({
    required this.newPassword,
  });

  @override
  List<Object?> get props => [newPassword];
}

class LoadNotificationSettingsRequested extends ProfileEvent {}

class UpdateNotificationSettingsRequested extends ProfileEvent {
  final NotificationSettings settings;

  const UpdateNotificationSettingsRequested(this.settings);

  @override
  List<Object?> get props => [settings];
}
