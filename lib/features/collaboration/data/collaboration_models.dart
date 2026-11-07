import 'package:equatable/equatable.dart';

enum SpaceKind { project, workspace }

extension SpaceKindPath on SpaceKind {
  String get path => this == SpaceKind.project ? 'projects' : 'workspaces';
  String get label => this == SpaceKind.project ? 'Проект' : 'Workspace';
}

class ManagedSpace extends Equatable {
  const ManagedSpace({
    required this.id,
    required this.name,
    this.raw = const {},
  });
  final String id;
  final String name;
  final Map<String, dynamic> raw;
  factory ManagedSpace.fromJson(Map<String, dynamic> json) => ManagedSpace(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    raw: Map.of(json),
  );
  Map<String, dynamic> toJson() => {...raw, 'id': id, 'name': name};
  ManagedSpace copyWith({
    String? id,
    String? name,
    Map<String, dynamic>? raw,
  }) => ManagedSpace(
    id: id ?? this.id,
    name: name ?? this.name,
    raw: raw ?? this.raw,
  );
  @override
  List<Object?> get props => [id, name, raw];
}

class SpaceMember extends Equatable {
  const SpaceMember({
    required this.userId,
    required this.name,
    this.email = '',
    this.role = 'EXECUTOR',
  });
  final String userId;
  final String name;
  final String email;
  final String role;
  factory SpaceMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : json;
    return SpaceMember(
      userId: (json['userId'] ?? user['id'] ?? '').toString(),
      name: (user['name'] ?? user['email'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      role: (json['role'] ?? 'EXECUTOR').toString(),
    );
  }
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'email': email,
    'role': role,
  };
  SpaceMember copyWith({
    String? userId,
    String? name,
    String? email,
    String? role,
  }) => SpaceMember(
    userId: userId ?? this.userId,
    name: name ?? this.name,
    email: email ?? this.email,
    role: role ?? this.role,
  );
  @override
  List<Object?> get props => [userId, name, email, role];
}

const memberRoles = {
  'SUPER_ADMIN': 'Суперадмин',
  'ADMIN': 'Администратор',
  'EXECUTOR': 'Участник',
};
String memberRoleLabel(String value) =>
    value == 'OWNER' ? 'Владелец' : memberRoles[value] ?? value;
