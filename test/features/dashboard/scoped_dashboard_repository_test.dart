import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/domain/dashboard_repository.dart';
import 'package:jospar/features/dashboard/domain/entities/dashboard_layout.dart';
import 'package:jospar/features/dashboard/domain/scoped_dashboard_repository.dart';
import 'package:jospar/features/dashboard/presentation/cubit/dashboard_layout_cubit.dart';

class _Repository implements DashboardRepository {
  final calls = <String>[];
  final Map<String, Completer<DashboardLayout>> pending = {};
  bool failSecond = false;

  @override
  Future<DashboardLayout> load(
    String workspaceId, {
    CancelToken? cancelToken,
  }) async => pending[workspaceId]?.future ?? DashboardLayout.defaults();

  @override
  Future<DashboardLayout> save(
    String workspaceId,
    DashboardLayout layout,
  ) async {
    calls.add('save:$workspaceId');
    return layout;
  }

  @override
  Future<List<Map<String, dynamic>>> tasks(
    String workspaceId,
    List<String> projectIds,
  ) async {
    calls.add('tasks:$workspaceId');
    if (failSecond && workspaceId == 'b') {
      throw const DashboardException('offline');
    }
    return [
      {'id': 'shared'},
      {'id': workspaceId},
    ];
  }

  @override
  Future<dynamic> widgetData(String workspaceId, String kind) async {
    calls.add('$kind:$workspaceId');
    if (kind == 'scrum-metadata') {
      return {
        'columns': [
          {'id': 'column-$workspaceId'},
        ],
        'epics': [
          {'id': 'epic-$workspaceId'},
        ],
      };
    }
    if (kind == 'recommendation-users') {
      return {
        'currentUser': {'id': 'me'},
        'users': [
          {'id': 'shared'},
          {'id': workspaceId},
        ],
      };
    }
    final rows = [
      {
        'id': workspaceId,
        'createdAt': workspaceId == 'b' ? '2026-11-27' : '2026-11-26',
      },
    ];
    return kind == 'team' ? {'members': rows} : rows;
  }
}

void main() {
  test(
    'combines tasks without duplicates and rejects incomplete results',
    () async {
      final delegate = _Repository();
      final repository = ScopedDashboardRepository(delegate, ['a', 'b']);
      expect((await repository.tasks('a', ['p'])).map((r) => r['id']), [
        'shared',
        'a',
        'b',
      ]);
      expect(delegate.calls, ['tasks:a', 'tasks:b']);
      delegate.failSecond = true;
      await expectLater(
        repository.tasks('a', ['p']),
        throwsA(isA<DashboardException>()),
      );
    },
  );

  test(
    'combines wrapped members, activity, metadata and recommendation users',
    () async {
      final repository = ScopedDashboardRepository(_Repository(), ['a', 'b']);
      expect(
        (await repository.widgetData('a', 'team') as List).map((r) => r['id']),
        ['a', 'b'],
      );
      expect(
        (await repository.widgetData('a', 'activity') as List).map(
          (r) => r['id'],
        ),
        ['b', 'a'],
      );
      final metadata =
          await repository.widgetData('a', 'scrum-metadata') as Map;
      expect((metadata['columns'] as List).map((r) => r['id']), [
        'column-a',
        'column-b',
      ]);
      final users =
          await repository.widgetData('a', 'recommendation-users') as Map;
      expect((users['users'] as List).map((r) => r['id']), [
        'shared',
        'a',
        'b',
      ]);
    },
  );

  test(
    'changing scope with the same primary invalidates cached dashboard data',
    () async {
      final delegate = _Repository();
      final cubit = DashboardLayoutCubit(delegate);
      addTearDown(cubit.close);
      await cubit.configure('me', 'a');
      await cubit.data('tasks', () => cubit.repository.tasks('a', ['p']));
      await cubit.configure('me', 'a', workspaceIds: ['a', 'b']);
      final rows =
          await cubit.data('tasks', () => cubit.repository.tasks('a', ['p']))
              as List;
      expect(rows.map((r) => r['id']), ['shared', 'a', 'b']);
      await cubit.repository.save('a', DashboardLayout.defaults());
      expect(delegate.calls.last, 'save:a');
      await cubit.configure('me', 'a', workspaceIds: ['a']);
      final single =
          await cubit.data('tasks', () => cubit.repository.tasks('a', ['p']))
              as List;
      expect(single.map((r) => r['id']), ['shared', 'a']);
    },
  );
}
