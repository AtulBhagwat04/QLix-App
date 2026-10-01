import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String id;
  final String fullName;
  final String email;
  final String organization;
  final String headline;
  final String bio;
  final String? avatarUrl;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.organization = '',
    this.headline = '',
    this.bio = '',
    this.avatarUrl,
  });

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? organization,
    String? headline,
    String? bio,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      organization: organization ?? this.organization,
      headline: headline ?? this.headline,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fullName,
        email,
        organization,
        headline,
        bio,
        avatarUrl,
      ];
}
