import 'models/space_kind_path.dart';
import 'models/managed_space_dto.dart';
import 'models/space_member_dto.dart';
import 'package:dio/dio.dart';
import '../domain/collaboration_repository.dart';
import '../domain/entities/managed_space.dart';
import '../domain/entities/space_member.dart';
import '../domain/entities/space_kind.dart';

class CollaborationRepositoryImpl implements CollaborationRepository {
  const CollaborationRepositoryImpl(this.dio);
  final Dio dio;
  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      throw CollaborationException(
        code == 403
            ? 'Недостаточно прав для этого действия.'
            : code == 404
            ? 'Объект больше недоступен. Обновите список.'
            : code == 409
            ? 'Действие невозможно: проверьте связанные проекты и участников.'
            : 'Не удалось выполнить действие. Попробуйте ещё раз.',
      );
    }
  }

  Map<String, dynamic> _object(dynamic data) {
    if (data is! Map) {
      throw const CollaborationException('Некорректный ответ сервера.');
    }
    final map = Map<String, dynamic>.from(data);
    for (final key in ['data', 'project', 'workspace']) {
      if (map[key] is Map) return Map<String, dynamic>.from(map[key] as Map);
    }
    return map;
  }

  List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) parse) {
    if (data is Map) {
      for (final key in [
        'data',
        'items',
        'members',
        'users',
        'projects',
        'workspaces',
      ]) {
        if (data[key] is List || data[key] is Map) {
          return _list(data[key], parse);
        }
      }
    }
    if (data is! List) {
      throw const CollaborationException('Некорректный список с сервера.');
    }
    return data
        .whereType<Map>()
        .map((e) => parse(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<ManagedSpace> getSpace(SpaceKind kind, String id) => _request(
    () async => ManagedSpaceDto.fromJson(
      _object(
        (await dio.get<dynamic>(
          '${kind.path}/${Uri.encodeComponent(id)}',
        )).data,
      ),
    ).toEntity(),
  );
  @override
  Future<void> updateSpace(
    SpaceKind kind,
    String id,
    Map<String, dynamic> changes,
  ) => _request(() async {
    await dio.patch<dynamic>(
      '${kind.path}/${Uri.encodeComponent(id)}',
      data: changes,
    );
  });
  @override
  Future<List<ManagedSpace>> archived(SpaceKind kind, {String? workspaceId}) =>
      _request(
        () async => _list(
          (await dio.get<dynamic>(
            '${kind.path}/archived',
            queryParameters: kind == SpaceKind.project
                ? {'workspaceId': workspaceId}
                : null,
          )).data,
          (json) => ManagedSpaceDto.fromJson(json).toEntity(),
        ),
      );
  @override
  Future<void> archive(SpaceKind kind, String id) => _request(() async {
    await dio.patch<dynamic>('${kind.path}/${Uri.encodeComponent(id)}/archive');
  });
  @override
  Future<void> restore(SpaceKind kind, String id) => _request(() async {
    await dio.patch<dynamic>('${kind.path}/${Uri.encodeComponent(id)}/restore');
  });
  @override
  Future<void> delete(SpaceKind kind, String id) => _request(() async {
    await dio.delete<dynamic>('${kind.path}/${Uri.encodeComponent(id)}');
  });
  @override
  Future<List<SpaceMember>> members(SpaceKind kind, String id) =>
      _request(() async {
        final data = (await dio.get<dynamic>(
          '${kind.path}/${Uri.encodeComponent(id)}/members',
        )).data;
        final members = _list(
          data,
          (json) => SpaceMemberDto.fromJson(json).toEntity(),
        );
        if (kind == SpaceKind.workspace && data is Map) {
          if (data['guests'] is List) {
            for (final guest in (data['guests'] as List).whereType<Map>()) {
              final member = SpaceMemberDto.fromJson({
                ...Map<String, dynamic>.from(guest),
                'access': 'GUEST',
              }).toEntity();
              if (!members.any((m) => m.userId == member.userId)) {
                members.add(member);
              }
            }
          }
          if (data['pendingInvites'] is List) {
            for (final invite
                in (data['pendingInvites'] as List).whereType<Map>()) {
              members.add(
                SpaceMemberDto.fromJson({
                  ...Map<String, dynamic>.from(invite),
                  'access': 'INVITATION',
                }).toEntity(),
              );
            }
          }
        }
        return members;
      });
  @override
  Future<List<SpaceMember>> candidates(String workspaceId) => _request(
    () async => _list(
      (await dio.get<dynamic>(
        workspaceId.isEmpty
            ? 'users'
            : 'workspaces/${Uri.encodeComponent(workspaceId)}/members',
      )).data,
      (json) => SpaceMemberDto.fromJson(json).toEntity(),
    ),
  );
  @override
  Future<void> addMember(
    SpaceKind kind,
    String id,
    String userId,
    String role,
  ) => _request(() async {
    await dio.post<dynamic>(
      '${kind.path}/${Uri.encodeComponent(id)}/members',
      data: {
        if (kind == SpaceKind.project) 'email': userId else 'userId': userId,
        if (kind == SpaceKind.project) 'role': role,
      },
    );
    if (kind == SpaceKind.workspace && role != 'EXECUTOR') {
      await updateRole(kind, id, userId, role);
    }
  });
  @override
  Future<void> updateRole(
    SpaceKind kind,
    String id,
    String userId,
    String role,
  ) => _request(() async {
    await dio.patch<dynamic>(
      '${kind.path}/${Uri.encodeComponent(id)}/members/${Uri.encodeComponent(userId)}${kind == SpaceKind.workspace ? '/role' : ''}',
      data: {'role': role},
    );
  });
  @override
  Future<void> removeMember(
    SpaceKind kind,
    String id,
    String userId,
  ) => _request(() async {
    await dio.delete<dynamic>(
      '${kind.path}/${Uri.encodeComponent(id)}/members/${Uri.encodeComponent(userId)}',
    );
  });
}
