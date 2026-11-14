import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/collaboration/data/collaboration_models.dart';
import 'package:jospar/features/collaboration/data/collaboration_repository_impl.dart';
import 'package:jospar/features/collaboration/domain/collaboration_repository.dart';
import 'package:jospar/features/collaboration/presentation/collaboration_cubit.dart';
import 'package:jospar/features/collaboration/presentation/archive_screen.dart';

void main() {
  test('failed refresh after saving does not report full success', () async {
    final adapter = _Adapter();
    final repo = CollaborationRepositoryImpl(Dio()..httpClientAdapter = adapter);
    final cubit = CollaborationCubit(repo, SpaceKind.workspace, 'w');
    addTearDown(cubit.close);
    await cubit.load();
    final result = await cubit.run(() async {
      await repo.updateSpace(SpaceKind.workspace, 'w', {'name': 'Новое'});
      adapter.forbidden = true;
    });
    expect(result, false);
    expect(cubit.state.saving, false);
    expect(cubit.state.space, isNotNull);
    expect(cubit.state.error, contains('Недостаточно прав'));
  });
  test(
    'project invitations use email while workspace membership uses user id',
    () async {
      final adapter = _Adapter();
      final repo = CollaborationRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      await repo.addMember(
        SpaceKind.project,
        'p',
        'member@example.test',
        'ADMIN',
      );
      expect(adapter.requests.last.data, {
        'email': 'member@example.test',
        'role': 'ADMIN',
      });
      await repo.addMember(SpaceKind.workspace, 'w', 'u', 'EXECUTOR');
      expect(adapter.requests.last.data, {'userId': 'u'});
      await repo.updateRole(SpaceKind.workspace, 'w', 'u', 'ADMIN');
      expect(adapter.requests.last.path, 'workspaces/w/members/u/role');
      await repo.updateRole(SpaceKind.project, 'p', 'u', 'EXECUTOR');
      expect(adapter.requests.last.path, 'projects/p/members/u');
    },
  );
  test(
    'wrapped project members and flattened workspace members preserve ids and roles',
    () {
      final project = SpaceMember.fromJson({
        'userId': 'u',
        'role': 'ADMIN',
        'user': {'id': 'u', 'name': 'Имя', 'email': 'a@b.test'},
      });
      final workspace = SpaceMember.fromJson({
        'id': 'u',
        'name': 'Имя',
        'role': 'EXECUTOR',
      });
      expect(project.userId, workspace.userId);
      expect(project.role, 'ADMIN');
      expect(project.email, 'a@b.test');
    },
  );
  test(
    'permission errors keep fields and members, failed writes can be retried',
    () async {
      final adapter = _Adapter();
      final repo = CollaborationRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      final cubit = CollaborationCubit(repo, SpaceKind.project, 'p');
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.members.single.userId, 'u');
      adapter.forbidden = true;
      expect(
        await cubit.run(
          () => repo.updateSpace(SpaceKind.project, 'p', {'name': 'Новое'}),
        ),
        false,
      );
      expect(cubit.state.space!.name, 'Проект');
      expect(cubit.state.members.single.userId, 'u');
      expect(cubit.state.saving, false);
      expect(cubit.state.error, contains('Недостаточно прав'));
      adapter.forbidden = false;
      expect(
        await cubit.run(
          () => repo.updateSpace(SpaceKind.project, 'p', {'name': 'Новое'}),
        ),
        true,
      );
      expect(cubit.state.space!.name, 'Новое');
      expect(cubit.state.error, isNull);
    },
  );
  test(
    'archive sends restore endpoint and keeps items after a failed delete',
    () async {
      final adapter = _Adapter();
      final repo = CollaborationRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      final cubit = ArchiveCubit(repo, SpaceKind.project, 'w');
      addTearDown(cubit.close);
      await cubit.load();
      expect(adapter.requests.last.queryParameters['workspaceId'], 'w');
      adapter.forbidden = true;
      await cubit.act('p', true);
      expect(cubit.state.items.single.id, 'p');
      expect(cubit.state.busyId, isNull);
      adapter.forbidden = false;
      await cubit.act('p', false);
      expect(adapter.requests.last.path, 'projects/p/restore');
      expect(cubit.state.items, isEmpty);
    },
  );
  test(
    'repository reports inaccessible objects without pretending success',
    () async {
      final adapter = _Adapter()..forbidden = true;
      final repo = CollaborationRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      expect(
        repo.delete(SpaceKind.workspace, 'w'),
        throwsA(isA<CollaborationException>()),
      );
    },
  );
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool forbidden = false;
  String name = 'Проект';
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    if (forbidden) return _json({'message': 'Forbidden'}, 403);
    if (options.method == 'PATCH' && options.path == 'projects/p') {
      name = (options.data as Map)['name'] as String;
    }
    if (options.path.endsWith('/archived')) {
      return _json([
        {'id': 'p', 'name': name},
      ]);
    }
    if (options.path.endsWith('/members') && options.method == 'GET') {
      return _json([
        {
          'userId': 'u',
          'role': 'ADMIN',
          'user': {'name': 'Участник', 'email': 'a@b.test'},
        },
      ]);
    }
    return _json({'id': 'p', 'name': name, 'workspaceId': 'w'});
  }

  ResponseBody _json(Object value, [int code = 200]) => ResponseBody.fromString(
    jsonEncode(value),
    code,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}
