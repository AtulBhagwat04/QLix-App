import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/error_handler.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _profileRepository;

  ProfileBloc(this._profileRepository) : super(ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
    on<UpdateProfileRequested>(_onUpdateProfileRequested);
    on<ChangePasswordRequested>(_onChangePasswordRequested);
    on<LoadNotificationSettingsRequested>(_onLoadNotificationSettingsRequested);
    on<UpdateNotificationSettingsRequested>(_onUpdateNotificationSettingsRequested);
  }

  Future<void> _onLoadProfile(
    LoadProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      final profile = await _profileRepository.getUserProfile();
      final notifications = await _profileRepository.getNotificationSettings();
      emit(ProfileLoaded(
        profile: profile,
        notificationSettings: notifications,
      ));
    } catch (e) {
      emit(ProfileFailure(AppError.from(e, context: 'profile')));
    }
  }

  Future<void> _onUpdateProfileRequested(
    UpdateProfileRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      emit(currentState.copyWith(isSaving: true, successMessage: null, errorMessage: null));
      try {
        final updated = await _profileRepository.updateUserProfile(event.profile);
        emit(currentState.copyWith(
          profile: updated,
          isSaving: false,
          successMessage: 'Profile updated successfully!',
        ));
      } catch (e) {
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: AppError.from(e, context: 'profile_update'),
        ));
      }
    }
  }

  Future<void> _onChangePasswordRequested(
    ChangePasswordRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      emit(currentState.copyWith(isSaving: true, successMessage: null, errorMessage: null));
      try {
        await _profileRepository.changePassword(
          newPassword: event.newPassword,
        );
        emit(currentState.copyWith(
          isSaving: false,
          successMessage: 'Password changed successfully!',
        ));
      } catch (e) {
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: AppError.from(e, context: 'password'),
        ));
      }
    }
  }

  Future<void> _onLoadNotificationSettingsRequested(
    LoadNotificationSettingsRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      try {
        final settings = await _profileRepository.getNotificationSettings();
        emit(currentState.copyWith(notificationSettings: settings));
      } catch (_) {}
    }
  }

  Future<void> _onUpdateNotificationSettingsRequested(
    UpdateNotificationSettingsRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      emit(currentState.copyWith(
        notificationSettings: event.settings,
        successMessage: null,
      ));
      try {
        await _profileRepository.updateNotificationSettings(event.settings);
        emit(currentState.copyWith(
          notificationSettings: event.settings,
          successMessage: 'Notification preferences saved',
        ));
      } catch (e) {
        emit(currentState.copyWith(
          errorMessage: 'Failed to save notifications',
        ));
      }
    }
  }
}
