import 'package:equatable/equatable.dart';
import '../../../../core/network/api_constants.dart';
import '../../domain/entities/space_member.dart';
import 'space_member_project_dto.dart';

class SpaceMemberDto extends Equatable {
  const SpaceMemberDto({
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
  factory SpaceMemberDto.fromEntity(SpaceMember entity) => SpaceMemberDto(
    userId: entity.userId,
    name: entity.name,
    email: entity.email,
    role: entity.role,
    avatarUrl: entity.avatarUrl,
    about: entity.about,
    access: entity.access,
    isWorkspaceOwner: entity.isWorkspaceOwner,
    details: {
      'isGuest': entity.isGuest,
      'projectCount': entity.projectCount,
      'lastActiveAt': entity.lastActiveAt,
      'projects': entity.projects
          .map((p) => SpaceMemberProjectDto.fromEntity(p).toJson())
          .toList(),
    },
  );
  SpaceMember toEntity() => SpaceMember(
    userId: userId,
    name: name,
    email: email,
    role: role,
    avatarUrl: avatarUrl,
    about: about,
    access: access,
    isWorkspaceOwner: isWorkspaceOwner,
    isGuest: details['isGuest'] == true,
    projectCount: details['projectCount'] is num
        ? (details['projectCount'] as num).toInt()
        : null,
    lastActiveAt: details['lastActiveAt']?.toString(),
    projects: details['projects'] is List
        ? (details['projects'] as List)
              .map((p) => SpaceMemberProjectDto.fromJson(p).toEntity())
              .toList()
        : const [],
  );
  static String? _resolveAvatar(String? value) {
    final source = value?.trim();
    if (source == null || source.isEmpty) return null;
    if (source.startsWith('data:image/')) return source;
    final uri = Uri.tryParse(source);
    if (uri == null) return null;
    final resolved = ApiConstants.origin.resolveUri(uri);
    return ['http', 'https'].contains(resolved.scheme)
        ? resolved.toString()
        : null;
  }

  final String userId;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final String about;
  final String access;
  final bool isWorkspaceOwner;
  final Map<String, dynamic> details;
  factory SpaceMemberDto.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : json;
    return SpaceMemberDto(
      userId: (json['userId'] ?? user['id'] ?? '').toString(),
      name: (user['name'] ?? user['email'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      role: (json['role'] ?? 'EXECUTOR').toString(),
      avatarUrl: _resolveAvatar(user['avatarUrl'] as String?),
      about: (user['about'] ?? '').toString(),
      access: (json['access'] ?? '').toString(),
      isWorkspaceOwner: json['isWorkspaceOwner'] == true,
      details: {
        for (final key in [
          'projects',
          'projectCount',
          'lastActiveAt',
          'isGuest',
        ])
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
  SpaceMemberDto copyWith({
    String? userId,
    String? name,
    String? email,
    String? role,
    String? avatarUrl,
    String? about,
    String? access,
    bool? isWorkspaceOwner,
    Map<String, dynamic>? details,
  }) => SpaceMemberDto(
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
