import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/tasks/data/repositories/task_details_repository_impl.dart';

void main() {
  test('rename patches only the trimmed title', () async {
    final adapter = _TaskDetailsAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
      ..httpClientAdapter = adapter;
    final repository = TaskDetailsRepositoryImpl(dio);
    await repository.updateTitle('task-1', '  Новое название  ');
    expect(adapter.titlePatch, {'title': 'Новое название'});
  });
  test('timing writes top-level est in hours and clears with zero', () async {
    final adapter = _TaskDetailsAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
      ..httpClientAdapter = adapter;
    final repository = TaskDetailsRepositoryImpl(dio);
    await repository.updateEstimate('task-1', 90);
    expect(adapter.updatedEstimate, 2);
    expect(adapter.updatedMinutes, 90);
    await repository.updateEstimate('task-1', 0);
    expect(adapter.updatedEstimate, 0);
    expect(adapter.updatedMinutes, 0);
    for (final action in ['start', 'pause', 'reset']) {
      await repository.timerAction('task-1', action);
      expect(adapter.lastTimerAction, action);
    }
  });
  test('loads full task and history and updates the detail payload', () async {
    final adapter = _TaskDetailsAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
      ..httpClientAdapter = adapter;
    final repository = TaskDetailsRepositoryImpl(dio);

    final payload = await repository.getTask('task-1');
    final history = await repository.getHistory('task-1');
    final columns = await repository.getColumns('project-1');
    await repository.updateDetail(
      'task-1',
      payload.detail.copyWith(description: 'Новое описание'),
    );

    expect(payload.task.title, 'Задача');
    expect(payload.resources.single.name, 'Бюджет');
    expect(history.single.type, 'task_created');
    expect(columns.single.name, 'Разработка');
    expect(adapter.updatedDescription, 'Новое описание');
  });
}

class _TaskDetailsAdapter implements HttpClientAdapter {
  Map<String, dynamic>? titlePatch;
  String? updatedDescription;
  num? updatedEstimate;
  int? updatedMinutes;
  String? lastTimerAction;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == 'kanban-columns') {
      expect(options.queryParameters['projectId'], 'project-1');
      return _jsonResponse(
        '[{"id":"column-1","projectId":"project-1",'
        '"name":"Разработка","statusMap":"PROGRESS"}]',
      );
    }
    if (options.path == 'project-tasks/task-1/history') {
      return _jsonResponse(
        '[{"id":"history-1","type":"task_created",'
        '"actorName":"Автор","createdAt":"2026-09-04T10:00:00Z"}]',
      );
    }
    if (options.path == 'project-tasks/task-1' && options.method == 'PATCH') {
      final body = Map<String, dynamic>.from(options.data as Map);
      if (body.containsKey('timerAction')) {
        lastTimerAction = body['timerAction'] as String;
        return _jsonResponse(_taskJson(description: 'Описание'));
      }
      if (body.containsKey('title')) {
        titlePatch = body;
        return _jsonResponse(_taskJson(description: 'Описание'));
      }
      if (body.containsKey('est')) {
        updatedEstimate = body['est'] as num;
        updatedMinutes = body['detail']['estimateMinutes'] as int;
        return _jsonResponse(_taskJson(description: 'Описание'));
      }
      final detail = Map<String, dynamic>.from(body['detail'] as Map);
      updatedDescription = detail['description'] as String?;
      return _jsonResponse(_taskJson(description: updatedDescription!));
    }
    if (options.path == 'project-tasks/task-1') {
      return _jsonResponse(_taskJson(description: 'Описание'));
    }
    return _jsonResponse('{}', statusCode: 404);
  }

  String _taskJson({required String description}) =>
      jsonEncode(<String, dynamic>{
        'id': 'task-1',
        'displayId': 'OPB-1',
        'projectId': 'project-1',
        'title': 'Задача',
        'status': 'TODO',
        'detail': <String, dynamic>{'description': description},
        'resources': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'resource-1',
            'name': 'Бюджет',
            'planValue': 100,
            'factValue': 50,
          },
        ],
      });

  ResponseBody _jsonResponse(String body, {int statusCode = 200}) {
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
