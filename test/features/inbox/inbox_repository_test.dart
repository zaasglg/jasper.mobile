import 'package:jospar/features/inbox/data/models/inbox_task_dto.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/inbox/data/repositories/inbox_repository_impl.dart';

void main() {
  test('menu actions use website endpoints and preserve task detail', () async {
    final adapter = _InboxApiAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
      ..httpClientAdapter = adapter;
    final repository = InboxRepositoryImpl(dio);
    final task = InboxTaskDto.fromJson({
      'id': 'inbox-1',
      'title': 'Отчёт',
      'start': '2026-10-16',
      'end': '2026-10-18',
      'priority': 'HIGH',
      'detail': {
        'description': 'Описание',
        'files': [
          {'id': 'file'},
        ],
        'labels': [
          {'id': 'tag', 'text': 'Работа'},
        ],
      },
    });
    final entity = task.toEntity();
    expect(entity.description, 'Описание');
    expect(InboxTaskDto.fromJson(task.toJson()), task);
    await repository.updateTask(task.id, {
      'detail': entity.detail,
      'end': null,
    });
    expect(adapter.lastRequest!.method, 'PATCH');
    expect(adapter.lastRequest!.path, 'inbox/inbox-1');
    expect(adapter.lastRequest!.data['detail']['files'], [
      {'id': 'file'},
    ]);
    expect(adapter.lastRequest!.data['end'], isNull);
    await repository.copyTask(entity);
    expect(adapter.lastRequest!.path, 'inbox');
    expect(adapter.lastRequest!.data['title'], 'Отчёт (копия)');
    expect(adapter.lastRequest!.data['detail'], task.detail);
    await repository.updateTask(task.id, {
      'detail': entity.detail.copyWith(
        description: 'Новое описание',
        labels: [],
      ),
    });
    expect(adapter.lastRequest!.data['detail'], {
      'description': 'Новое описание',
      'labels': [],
      'files': [
        {'id': 'file'},
      ],
    });

    await repository.moveTask(task.id, 'project');
    expect(adapter.lastRequest!.path, 'inbox/inbox-1/move');
    expect(adapter.lastRequest!.data['projectId'], 'project');
    await repository.deleteTask(task.id);
    expect(adapter.lastRequest!.method, 'DELETE');
    expect(adapter.lastRequest!.path, 'inbox/inbox-1');
  });

  test('loads inbox with archived and sort query parameters', () async {
    final adapter = _InboxApiAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
      ..httpClientAdapter = adapter;
    final repository = InboxRepositoryImpl(dio);

    final tasks = await repository.getInbox(archived: true, sort: 1);

    expect(adapter.archived, 1);
    expect(adapter.sort, 1);
    expect(tasks, hasLength(1));
    expect(tasks.single.id, 'inbox-1');
    expect(tasks.single.title, 'Подготовить отчёт');
    expect(tasks.single.completed, isFalse);
  });

  test('InboxTaskDto parses alternative API field names', () {
    final task = InboxTaskDto.fromJson(<String, dynamic>{
      'task_id': 'inbox-2',
      'subject': 'Проверить договор',
      'display_id': 'IN-2',
      'isCompleted': 1,
      'isArchived': 'true',
      'position': '4',
      'created_at': '2026-09-05T08:00:00.000Z',
    });

    expect(task.id, 'inbox-2');
    expect(task.displayId, 'IN-2');
    expect(task.completed, isTrue);
    expect(task.archived, isTrue);
    expect(task.order, 4);
    expect(task.toJson()['title'], 'Проверить договор');
  });

  test('creates an inbox task with its title', () async {
    final adapter = _InboxApiAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
      ..httpClientAdapter = adapter;
    final repository = InboxRepositoryImpl(dio);

    await repository.createInbox(title: '  Новая задача  ');

    expect(adapter.createdTitle, 'Новая задача');
  });

  test('completes an inbox task using documented endpoint', () async {
    final adapter = _InboxApiAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
      ..httpClientAdapter = adapter;
    final repository = InboxRepositoryImpl(dio);

    await repository.completeInboxTask(id: 'inbox-1');

    expect(adapter.completedTaskId, 'inbox-1');
  });
}

class _InboxApiAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  int? archived;
  int? sort;
  String? createdTitle;
  String? completedTaskId;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (options.path == 'inbox/inbox-1' ||
        options.path == 'inbox/inbox-1/move') {
      return _jsonResponse('{}');
    }
    if (options.path == 'inbox' && options.method == 'GET') {
      archived = options.queryParameters['archived'] as int?;
      sort = options.queryParameters['sort'] as int?;
      return _jsonResponse(
        '{"data":{"items":[{"id":"inbox-1",'
        '"title":"Подготовить отчёт","completed":false}]}}',
      );
    }
    if (options.path == 'inbox' && options.method == 'POST') {
      createdTitle = (options.data as Map<String, dynamic>)['title'] as String?;
      return _jsonResponse('{}', statusCode: 201);
    }
    final completeMatch = RegExp(
      r'^inbox/([^/]+)/complete$',
    ).firstMatch(options.path);
    if (completeMatch != null && options.method == 'POST') {
      completedTaskId = completeMatch.group(1);
      return _jsonResponse('{}', statusCode: 201);
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
