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
    this.avatarUrl,
    this.about = '',
    this.access = '',
    this.isWorkspaceOwner = false,
    this.details = const {},
  });
  final String userId;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final String about;
  final String access;
  final bool isWorkspaceOwner;
  final Map<String, dynamic> details;
  factory SpaceMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : json;
    return SpaceMember(
      userId: (json['userId'] ?? user['id'] ?? '').toString(),
      name: (user['name'] ?? user['email'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      role: (json['role'] ?? 'EXECUTOR').toString(),
      avatarUrl: user['avatarUrl'] as String?,
      about: (user['about'] ?? '').toString(),
      access: (json['access'] ?? '').toString(),
      isWorkspaceOwner: json['isWorkspaceOwner'] == true,
      details: {
        for (final key in ['projects', 'projectCount', 'lastActiveAt', 'isGuest'])
          if (json.containsKey(key) || user.containsKey(key))
            key: json[key] ?? user[key],
      },
    );
  }
  Map<String, dynamic> toJson() => {
    ...details,
    'userId': userId,
    'name': name,
    'email': email,
    'role': role,
    'avatarUrl': avatarUrl,
    'about': about,
    'access': access,
    'isWorkspaceOwner': isWorkspaceOwner,
  };
  SpaceMember copyWith({
    String? userId,
    String? name,
    String? email,
    String? role,
    String? avatarUrl,
    String? about,
    String? access,
    bool? isWorkspaceOwner,
    Map<String, dynamic>? details,
  }) => SpaceMember(
    userId: userId ?? this.userId,
    name: name ?? this.name,
    email: email ?? this.email,
    role: role ?? this.role,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    about: about ?? this.about,
    access: access ?? this.access,
    isWorkspaceOwner: isWorkspaceOwner ?? this.isWorkspaceOwner,
    details: details ?? this.details,
  );
  @override
  List<Object?> get props => [
    userId,
    name,
    email,
    role,
    avatarUrl,
    about,
    access,
    isWorkspaceOwner,
    details,
  ];
}

const memberRoles = {
  'SUPER_ADMIN': 'Суперадмин',
  'ADMIN': 'Администратор',
  'EXECUTOR': 'Участник',
};
String memberRoleLabel(String value) =>
    value == 'OWNER' ? 'Владелец' : memberRoles[value] ?? value;
