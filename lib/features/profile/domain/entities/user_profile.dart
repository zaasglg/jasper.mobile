import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.role = '',
    this.locale = 'ru',
  });

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String role;
  final String locale;

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
    String? locale,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      locale: locale ?? this.locale,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    email,
    avatarUrl,
    role,
    locale,
  ];
}
