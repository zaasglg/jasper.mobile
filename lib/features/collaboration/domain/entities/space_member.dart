import 'package:equatable/equatable.dart';
import 'space_member_project.dart';

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
    this.isGuest = false,
    this.projectCount,
    this.lastActiveAt,
    this.projects = const [],
  });
  final String userId;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final String about;
  final String access;
  final bool isWorkspaceOwner;
  final bool isGuest;
  final int? projectCount;
  final String? lastActiveAt;
  final List<SpaceMemberProject> projects;
  SpaceMember copyWith({
    String? userId,
    String? name,
    String? email,
    String? role,
    String? avatarUrl,
    String? about,
    String? access,
    bool? isWorkspaceOwner,
    bool? isGuest,
    int? projectCount,
    String? lastActiveAt,
    List<SpaceMemberProject>? projects,
  }) => SpaceMember(
    userId: userId ?? this.userId,
    name: name ?? this.name,
    email: email ?? this.email,
    role: role ?? this.role,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    about: about ?? this.about,
    access: access ?? this.access,
    isWorkspaceOwner: isWorkspaceOwner ?? this.isWorkspaceOwner,
    isGuest: isGuest ?? this.isGuest,
    projectCount: projectCount ?? this.projectCount,
    lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    projects: projects ?? this.projects,
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
    isGuest,
    projectCount,
    lastActiveAt,
    projects,
  ];
}
