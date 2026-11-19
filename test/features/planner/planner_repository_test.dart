import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/data/repositories/planner_repository_impl.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';

void main() {
  test(
    'updates planner entries without changing linked project or inbox tasks',
    () async {
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
        ..httpClientAdapter = adapter;
      final repo = PlannerRepositoryImpl(dio);
      await repo.create(
        title: ' План ',
        scheduledAt: DateTime.utc(2026, 10, 10, 4),
        durationMinutes: 45,
      );
      expect(adapter.requests.last.path, 'project-planner/account/tasks');
      expect(adapter.requests.last.data, {
        'title': 'План',
        'scheduledAt': '2026-10-10T04:00:00.000Z',
        'durationMinutes': 45,
      });
      await repo.update(
        const PlannerItemModel(id: 'standalone', title: 'Plan'),
        completed: true,
      );
      expect(adapter.requests.last.path, 'project-planner/items/standalone');
      expect(adapter.requests.last.data, {'completed': true});
      await repo.update(
        const PlannerItemModel(
          id: 'item',
          title: 'Task',
          taskId: 'task',
          task: ProjectTaskModel(id: 'task', projectId: 'p', status: 'DONE'),
        ),
        completed: false,
      );
      expect(
        adapter.requests.last.path,
        'project-planner/items/item/completion',
      );
      expect(adapter.requests.last.data, {'completed': false});
      await repo.update(
        const PlannerItemModel(
          id: 'inbox-item',
          title: 'Inbox',
          inboxTaskId: 'inbox',
        ),
        completed: true,
      );
      expect(
        adapter.requests.last.path,
        'project-planner/items/inbox-item/completion',
      );
      expect(adapter.requests.last.data, {'completed': true});
      expect(
        adapter.requests.any((r) => r.path.startsWith('project-tasks/')),
        isFalse,
      );
      await repo.addTask(
        inboxTaskId: 'inbox',
        scheduledAt: DateTime.utc(2026, 10, 10, 4),
        durationMinutes: 30,
      );
      expect(adapter.requests.last.path, 'project-planner/account/inbox-tasks');
      expect((adapter.requests.last.data as Map)['inboxTaskId'], 'inbox');
      await repo.addTask(
        projectId: 'original-project',
        taskId: 'original-task',
        scheduledAt: DateTime.utc(2026, 10, 10, 4),
        durationMinutes: 30,
      );
      expect(
        adapter.requests.last.path,
        'project-planner/original-project/tasks',
      );
      expect(adapter.requests.last.data, {
        'taskId': 'original-task',
        'scheduledAt': '2026-10-10T04:00:00.000Z',
        'durationMinutes': 30,
      });
      await repo.remove('item');
      expect(adapter.requests.last.method, 'DELETE');
      expect(adapter.requests.last.path, 'project-planner/items/item');
    },
  );
  test(
    'old server cannot turn a planner check into project completion',
    () async {
      final adapter = _Adapter()..status = 404;
      final repo = PlannerRepositoryImpl(Dio()..httpClientAdapter = adapter);
      await expectLater(
        repo.update(
          const PlannerItemModel(id: 'item', title: 'Plan', taskId: 'task'),
          completed: true,
        ),
        throwsA(
          isA<PlannerException>().having(
            (e) => e.message,
            'message',
            contains('обновлённый сервер'),
          ),
        ),
      );
      expect(
        adapter.requests.single.path,
        'project-planner/items/item/completion',
      );
    },
  );
  test('linked task status and archive do not replace planner state', () async {
    final adapter = _Adapter()
      ..response = (_) => [
        {
          'id': 'planned',
          'completed': true,
          'task': {
            'id': 'task',
            'projectId': 'p',
            'progress': 0,
            'archived': true,
          },
        },
        {
          'id': 'unfinished',
          'completed': false,
          'task': {'id': 'done-task', 'projectId': 'p', 'status': 'DONE'},
        },
        {
          'id': 'inbox-plan',
          'completed': false,
          'inboxTaskId': 'inbox',
          'inboxTask': {'id': 'inbox', 'completed': true, 'archived': true},
        },
        {'id': 'archived-plan', 'archived': true},
      ];
    final repo = PlannerRepositoryImpl(Dio()..httpClientAdapter = adapter);
    final items = await repo.load();
    expect(items.map((item) => item.id), [
      'planned',
      'unfinished',
      'inbox-plan',
    ]);
    expect(items.map((item) => item.completed), [true, false, false]);
    expect(items.map((item) => item.archived), everyElement(false));
  });

  test('planner completion survives reloads and source task changes', () async {
    var plannedCompleted = false;
    var sourceDone = false;
    final adapter = _Adapter()
      ..response = (request) {
        if (request.method == 'PATCH') {
          expect(request.path, 'project-planner/items/slot/completion');
          plannedCompleted = (request.data as Map)['completed'] as bool;
          return {};
        }
        return [
          {
            'id': 'slot',
            'completed': plannedCompleted,
            'task': {
              'id': 'task',
              'projectId': 'project',
              'title': 'Source',
              'progress': sourceDone ? 100 : 0,
              'status': sourceDone ? 'DONE' : 'TODO',
              'archived': sourceDone,
            },
          },
        ];
      };
    final cubit = PlannerCubit(
      PlannerRepositoryImpl(Dio()..httpClientAdapter = adapter),
    );
    addTearDown(cubit.close);
    await cubit.initialize();
    await cubit.toggle(cubit.state.items.single);
    await cubit.refresh();
    expect(cubit.state.items.single.completed, isTrue);
    expect(cubit.state.items.single.task!.isDone, isFalse);
    sourceDone = true;
    await cubit.refresh();
    await cubit.toggle(cubit.state.items.single);
    await cubit.refresh();
    expect(cubit.state.items.single.completed, isFalse);
    expect(cubit.state.items.single.task!.isDone, isTrue);
    expect(cubit.state.items.single.archived, isFalse);
  });

  for (final archived in [false, true]) {
    test('rejects repeated full planner pages (archived: $archived)', () async {
      final adapter = _Adapter()
        ..response = (_) =>
            List.generate(250, (i) => {'id': 'entry-$i', 'archived': archived});
      final repo = PlannerRepositoryImpl(Dio()..httpClientAdapter = adapter);
      // Bound the broken implementation too, so a regression cannot hang tests.
      final page = adapter.response!;
      adapter.response = (request) {
        if (adapter.requests.length > 3) {
          throw StateError('Pagination did not stop');
        }
        return page(request);
      };
      await expectLater(repo.load(), throwsA(isA<PlannerException>()));
      expect(adapter.requests.length, 2);
    });
  }
  test(
    'loads every account page across workspaces and filters archived entries',
    () async {
      final adapter = _Adapter();
      adapter.response = (options) {
        final skip = options.queryParameters['skip'] as int;
        if (skip == 0) {
          return List.generate(
            250,
            (i) => {
              'id': 'item-$i',
              'title': 'Entry $i',
              'workspaceId': i.isEven ? 'a' : 'b',
              'archived': i == 1,
            },
          );
        }
        return [
          {'id': 'personal', 'title': 'Personal', 'workspaceId': null},
        ];
      };
      final repo = PlannerRepositoryImpl(
        Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
          ..httpClientAdapter = adapter,
      );
      final items = await repo.load();
      expect(items.length, 250);
      expect(items.last.id, 'personal');
      expect(items.any((item) => item.id == 'item-1'), isFalse);
      expect(
        adapter.requests.map((r) => r.path),
        everyElement('project-planner/account'),
      );
      expect(adapter.requests.map((r) => r.queryParameters), [
        {'skip': 0, 'take': 250},
        {'skip': 250, 'take': 250},
      ]);
    },
  );
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  Object Function(RequestOptions)? response;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(response?.call(options) ?? {'id': 'new', 'title': 'Plan'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
