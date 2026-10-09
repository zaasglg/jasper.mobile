import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/inbox/data/models/inbox_task_model.dart';
import 'package:jospar/features/inbox/data/repositories/inbox_repository_impl.dart';

void main() {
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

  test('InboxTaskModel parses alternative API field names', () {
    final task = InboxTaskModel.fromJson(<String, dynamic>{
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
