import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/data/repositories/planner_repository_impl.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';

void main() {
  test(
    'uses account planner endpoints and separates project completion from standalone completion',
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
      expect(adapter.requests.last.path, 'project-tasks/task');
      expect(adapter.requests.last.data, {'progress': 0, 'status': 'TODO'});
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
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
