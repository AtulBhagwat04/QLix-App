import 'package:equatable/equatable.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/entities/user_profile.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final UserProfile profile;
  final NotificationSettings notificationSettings;
  final bool isSaving;
  final String? successMessage;
  final String? errorMessage;

  const ProfileLoaded({
    required this.profile,
    required this.notificationSettings,
    this.isSaving = false,
    this.successMessage,
    this.errorMessage,
  });

  ProfileLoaded copyWith({
    UserProfile? profile,
    NotificationSettings? notificationSettings,
    bool? isSaving,
    String? successMessage,
    String? errorMessage,
  }) {
    return ProfileLoaded(
      profile: profile ?? this.profile,
      notificationSettings:
          notificationSettings ?? this.notificationSettings,
      isSaving: isSaving ?? this.isSaving,
      successMessage: successMessage,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        profile,
        notificationSettings,
        isSaving,
        successMessage,
        errorMessage,
      ];
}

class ProfileFailure extends ProfileState {
  final String message;

  const ProfileFailure(this.message);

  @override
  List<Object?> get props => [message];
}
