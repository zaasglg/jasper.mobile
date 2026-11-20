import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.role = '',
  });

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String role;

  String get roleLabel => switch (role.trim().toUpperCase()) {
    'SUPER_ADMIN' || 'SUPERADMIN' => 'Суперадмин',
    'ADMIN' => 'Админ',
    'EXECUTOR' || 'MEMBER' || 'USER' => 'Участник',
    'OWNER' => 'Владелец',
    '' => 'Не указана',
    _ => role,
  };

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? role,
  }) {
    return UserProfile(
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
