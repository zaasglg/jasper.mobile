import '../../../../core/network/api_constants.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/user_profile.dart';

class UserProfileDto extends Equatable {
  const UserProfileDto({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.role = '',
  });

  factory UserProfileDto.fromJson(Map<String, dynamic> json) {
    final rawAvatarUrl =
        json['avatarUrl'] ?? json['avatar_url'] ?? json['avatar'];

    return UserProfileDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      avatarUrl: rawAvatarUrl is String && rawAvatarUrl.trim().isNotEmpty
          ? _resolveAvatarUrl(rawAvatarUrl.trim())
          : null,
    );
  }

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String role;

  factory UserProfileDto.fromEntity(UserProfile entity) => UserProfileDto(
    id: entity.id,
    name: entity.name,
    email: entity.email,
    avatarUrl: entity.avatarUrl,
    role: entity.role,
  );

  UserProfile toEntity() => UserProfile(
    id: id,
    name: name,
    email: email,
    avatarUrl: avatarUrl,
    role: role,
  );

  static String _resolveAvatarUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    return ApiConstants.origin.resolve(value).toString();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'email': email,
    'avatarUrl': avatarUrl,
    'role': role,
  };

  UserProfileDto copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? role,
  }) {
    return UserProfileDto(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, name, email, avatarUrl, role];
}
