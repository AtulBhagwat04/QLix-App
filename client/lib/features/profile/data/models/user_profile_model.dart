import '../../domain/entities/user_profile.dart';

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.id,
    required super.fullName,
    required super.email,
    super.organization,
    super.headline,
    super.bio,
    super.avatarUrl,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      organization: json['organization'] as String? ?? '',
      headline: json['headline'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  factory UserProfileModel.fromEntity(UserProfile entity) {
    return UserProfileModel(
      id: entity.id,
      fullName: entity.fullName,
      email: entity.email,
      organization: entity.organization,
      headline: entity.headline,
      bio: entity.bio,
      avatarUrl: entity.avatarUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'organization': organization,
      'headline': headline,
      'bio': bio,
      'avatarUrl': avatarUrl,
    };
  }
}
