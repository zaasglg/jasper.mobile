import 'package:jospar/features/collaboration/data/models/space_member_dto.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/collaboration/domain/entities/space_kind.dart';
import 'package:jospar/features/collaboration/data/collaboration_repository_impl.dart';
import 'package:jospar/features/collaboration/domain/collaboration_repository.dart';
import 'package:jospar/features/collaboration/presentation/collaboration_cubit.dart';
import 'package:jospar/features/collaboration/presentation/archive_screen.dart';

void main() {
  test('failed refresh after saving does not report full success', () async {
    final adapter = _Adapter();
    final repo = CollaborationRepositoryImpl(
      Dio()..httpClientAdapter = adapter,
    );
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
      final project = SpaceMemberDto.fromJson({
        'userId': 'u',
        'role': 'ADMIN',
        'user': {'id': 'u', 'name': 'Имя', 'email': 'a@b.test'},
      });
      final workspace = SpaceMemberDto.fromJson({
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

  for (final dark in [false, true]) {
    testWidgets(
      'ArchiveScreen renders cards, filters by search and restores item, dark: $dark',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        final adapter = _Adapter();
        final repo = CollaborationRepositoryImpl(
          Dio()..httpClientAdapter = adapter,
        );
        sl.registerFactory<CollaborationRepository>(() => repo);
        addTearDown(() async {
          if (sl.isRegistered<CollaborationRepository>()) {
            await sl.unregister<CollaborationRepository>();
          }
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: const ArchiveScreen(
              kind: SpaceKind.project,
              workspaceId: 'w',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Архив проектов'), findsOneWidget);
        expect(find.text('Проект'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('archive-search')), 'нет');
        await tester.pumpAndSettle();
        expect(find.text('Ничего не найдено'), findsOneWidget);
        await tester.tap(find.text('Сбросить поиск'));
        await tester.pumpAndSettle();
        expect(find.text('Проект'), findsOneWidget);
        await tester.tap(find.text('Проект'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Восстановить'));
        await tester.pumpAndSettle();
        expect(find.text('Архив пуст'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
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
