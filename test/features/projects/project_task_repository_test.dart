import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/projects/data/repositories/project_task_repository_impl.dart';

void main() {
  test('requests only provided project ids and parses tasks', () async {
    final adapter = _TaskAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
      ..httpClientAdapter = adapter;
    final repository = ProjectTaskRepositoryImpl(dio);

    final tasks = await repository.getTasksForProjectIds(<String>[
      'root',
      'child',
      'root',
      '',
    ]);

    expect(adapter.path, '/api/project-tasks');
    expect(adapter.projectIds, 'root,child');
    expect(tasks.single.id, 'task-1');
    expect(tasks.single.projectId, 'child');
    expect(tasks.single.isDone, isTrue);
  });
}

class _TaskAdapter implements HttpClientAdapter {
  String? path;
  String? projectIds;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.uri.path;
    projectIds = options.queryParameters['projectIds'] as String?;
    return ResponseBody.fromString(
      '{"data":[{"id":"task-1","projectId":"child",'
      '"status":"IN_PROGRESS","progress":100}]}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
