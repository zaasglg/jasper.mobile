import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/data/repositories/planner_repository_impl.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';

void main() {
  test(
    'uses website planner endpoints and separates project completion from standalone completion',
    () async {
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
        ..httpClientAdapter = adapter;
      final repo = PlannerRepositoryImpl(dio);
      await repo.create(
        'workspace',
        title: ' План ',
        scheduledAt: DateTime.utc(2026, 10, 10, 4),
        durationMinutes: 45,
      );
      expect(
        adapter.requests.last.path,
        'project-planner/workspace/workspace/tasks',
      );
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
        'workspace',
        inboxTaskId: 'inbox',
        scheduledAt: DateTime.utc(2026, 10, 10, 4),
        durationMinutes: 30,
      );
      expect(
        adapter.requests.last.path,
        'project-planner/workspace/workspace/inbox-tasks',
      );
      expect((adapter.requests.last.data as Map)['inboxTaskId'], 'inbox');
      await repo.remove('item');
      expect(adapter.requests.last.method, 'DELETE');
      expect(adapter.requests.last.path, 'project-planner/items/item');
    },
  );
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'id': 'new', 'title': 'Plan'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
