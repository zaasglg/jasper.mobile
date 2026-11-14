import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'collaboration_models.dart';
import 'collaboration_repository_impl.dart';
import '../domain/collaboration_repository.dart';

class ProjectInvitation extends Equatable {
  const ProjectInvitation(this.email, this.role);
  final String email;
  final String role;
  factory ProjectInvitation.fromJson(Map<String, dynamic> json) =>
      ProjectInvitation(json['email'] as String, json['role'] as String);
  Map<String, dynamic> toJson() => {'email': email, 'role': role};
  ProjectInvitation copyWith({String? email, String? role}) =>
      ProjectInvitation(email ?? this.email, role ?? this.role);
  @override
  List<Object?> get props => [email, role];
}

class ProjectAccessLink extends Equatable {
  const ProjectAccessLink({required this.url, required this.role});
  final String url;
  final String role;
  factory ProjectAccessLink.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const CollaborationException('Сервер вернул некорректную ссылку.');
    }
    return ProjectAccessLink(url: url, role: json['role'] as String);
  }
  Map<String, dynamic> toJson() => {'url': url, 'role': role};
  ProjectAccessLink copyWith({String? url, String? role}) =>
      ProjectAccessLink(url: url ?? this.url, role: role ?? this.role);
  @override
  List<Object?> get props => [url, role];
}

/// All grants and mutations are scoped to a project, never a workspace role.
class ProjectParticipantsRepository {
  ProjectParticipantsRepository(this.dio)
    : collaboration = CollaborationRepositoryImpl(dio);
  final Dio dio;
  final CollaborationRepositoryImpl collaboration;
  String path(String id) => 'projects/${Uri.encodeComponent(id)}';

  Future<T> request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final message = body is Map ? body['message'] : null;
      throw CollaborationException(
        status == 403
            ? 'Недостаточно прав для этого действия.'
            : status == 401
            ? 'Войдите в аккаунт повторно.'
            : status == 404
            ? 'Проект или участник больше недоступен.'
            : (status == 400 || status == 409) && message is String
            ? message
            : 'Не удалось связаться с сервером. Проверьте подключение и повторите попытку.',
      );
    }
  }

  Future<({List<SpaceMember> members, List<ProjectInvitation> invitations})>
  members(String id) => request(() async {
    final data = (await dio.get<Map<String, dynamic>>(
      '${path(id)}/members',
    )).data!;
    return (
      members: (data['members'] as List)
          .map((e) => SpaceMember.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      invitations: (data['pendingInvites'] as List? ?? [])
          .map(
            (e) =>
                ProjectInvitation.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  });
  Future<String> myRole(String id) => request(
    () async =>
        (await dio.get<Map<String, dynamic>>(
              '${path(id)}/members/me',
            )).data!['role']
            as String,
  );
  Future<String> myId() => request(
    () async =>
        (await dio.get<Map<String, dynamic>>('users/me')).data!['id'] as String,
  );
  Future<ProjectAccessLink?> link(String id) => request(() async {
    final data = (await dio.get<Map<String, dynamic>>(
      '${path(id)}/invite-link/current',
    )).data;
    return data == null ? null : ProjectAccessLink.fromJson(data);
  });
  Future<ProjectAccessLink> createLink(String id, String role) => request(
    () async => ProjectAccessLink.fromJson(
      (await dio.post<Map<String, dynamic>>(
        '${path(id)}/invite-link/regenerate',
        data: {'role': role},
      )).data!,
    ),
  );
  Future<ProjectAccessLink> changeLinkRole(String id, String role) => request(
    () async => ProjectAccessLink.fromJson(
      (await dio.patch<Map<String, dynamic>>(
        '${path(id)}/invite-link',
        data: {'role': role},
      )).data!,
    ),
  );
  Future<void> revokeLink(String id) => request(() async {
    await dio.delete<dynamic>('${path(id)}/invite-link');
  });
  Future<void> changeRole(String id, String userId, String role) =>
      request(() async {
        await dio.patch<dynamic>(
          '${path(id)}/members/${Uri.encodeComponent(userId)}',
          data: {'role': role},
        );
      });
  Future<void> remove(String id, String userId) => request(() async {
    await dio.delete<dynamic>(
      '${path(id)}/members/${Uri.encodeComponent(userId)}',
    );
  });
  Future<void> add(String id, String email, String role) => request(() async {
    await dio.post<dynamic>(
      '${path(id)}/members',
      data: {'email': email.trim().toLowerCase(), 'role': role},
    );
  });
}

bool isInvitationEmail(String value) {
  final email = value.trim();
  final parts = email.split('@');
  if (email.length > 254 || parts.length != 2 || parts.first.length > 64) {
    return false;
  }
  final local = parts.first;
  if (local.startsWith('.') || local.endsWith('.') || local.contains('..')) {
    return false;
  }
  return RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+$").hasMatch(local) &&
      RegExp(
        r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$',
      ).hasMatch(parts.last);
}

List<String> assignableProjectRoles(String role) => switch (role) {
  'SUPER_ADMIN' => ['SUPER_ADMIN', 'ADMIN', 'EXECUTOR'],
  'ADMIN' => ['ADMIN', 'EXECUTOR'],
  _ => [],
};
