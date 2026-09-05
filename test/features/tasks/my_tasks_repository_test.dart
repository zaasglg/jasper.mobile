import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/tasks/data/repositories/my_tasks_repository_impl.dart';

void main() {
  test(
    'uses assignee/project queries, parses columns, and patches progress',
    () async {
      final adapter = _ApiAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
        ..httpClientAdapter = adapter;
      final repository = MyTasksRepositoryImpl(dio);

      final tasks = await repository.getTasks(
        assigneeId: 'user-1',
        projectIds: <String>['root', 'child'],
      );
      final columns = await repository.getKanbanColumns('root');
      await repository.updateProgress('task-1', 100);

      expect(adapter.assigneeId, 'user-1');
      expect(adapter.projectIds, 'root,child');
      expect(tasks.single.displayId, 'ORB-1');
      expect(tasks.single.epicNames, <String>['Архитектура']);
      expect(columns.single.statusMap, 'TODO');
      expect(adapter.patchedTaskId, 'task-1');
      expect(adapter.patchedProgress, 100);
    },
  );
}

class _ApiAdapter implements HttpClientAdapter {
  String? assigneeId;
  String? projectIds;
  String? patchedTaskId;
  int? patchedProgress;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == 'project-tasks' && options.method == 'GET') {
      assigneeId = options.queryParameters['assigneeId'] as String?;
      projectIds = options.queryParameters['projectIds'] as String?;
      return _jsonResponse(
        '[{"id":"task-1","displayId":"ORB-1","title":"Задача",'
        '"projectId":"root","status":"TODO","progress":20,'
        '"epics":[{"epic":{"id":"e1","name":"Архитектура"}}]}]',
      );
    }
    if (options.path == 'kanban-columns') {
      return _jsonResponse(
        '[{"id":"column-1","name":"К работе","statusMap":"TODO"}]',
      );
    }
    if (options.path.startsWith('project-tasks/') &&
        options.method == 'PATCH') {
      patchedTaskId = options.path.split('/').last;
      final data = Map<String, dynamic>.from(options.data as Map);
      patchedProgress = data['progress'] as int?;
      return _jsonResponse('{}');
    }
    return _jsonResponse('{}', statusCode: 404);
  }

  ResponseBody _jsonResponse(String body, {int statusCode = 200}) {
    jsonDecode(body);
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
