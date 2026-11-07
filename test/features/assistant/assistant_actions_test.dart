import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/assistant/data/services/assistant_actions.dart';
import 'package:jospar/features/assistant/domain/repositories/assistant_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const selection = WorkspaceSelectionStorage(FlutterSecureStorage());
  late _Server server;
  late AssistantActions actions;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'selected_workspace_id': 'w'});
    server = _Server();
    actions = AssistantActions(
      Dio(BaseOptions(baseUrl: 'https://example.test/'))
        ..httpClientAdapter = server,
      selection,
    );
  });
  final draft = <String, dynamic>{
    'type': 'task_edit_draft',
    'workspaceId': 'w',
    'projectId': 'p',
    'taskId': 't',
    'title': 'До',
    'patch': {'title': 'После', 'end': '2026-12-01'},
    'previous': {'title': 'До', 'end': null},
  };
  test(
    'extraction forwards project and images but never creates a task',
    () async {
      server.responses.add({
        'isTaskDetected': true,
        'suggestedTask': {'title': 'Проверить смету', 'dueDate': null},
        'resolvedAssigneeId': 'u',
      });
      final result = await actions.extract('w', 'Создай задачу', [
        'data:image/png;base64,abc',
      ], 'p');
      expect(result!['resolvedAssigneeId'], 'u');
      expect(server.requests.single.path, 'ai/extract-task');
      expect(server.requests.single.data, {
        'workspaceId': 'w',
        'messageText': 'Создай задачу',
        'projectId': 'p',
        'images': ['data:image/png;base64,abc'],
      });
      expect(server.requests.single.headers['X-Workspace-Id'], 'w');
    },
  );
  test(
    'confirmation validates project workspace and sends resolved assignee',
    () async {
      server.responses.addAll([
        [
          {'id': 'p', 'workspaceId': 'w', 'name': 'Проект'},
        ],
        {'id': 'created'},
      ]);
      await actions.create('w', 'p', {
        'title': 'Новая',
        'description': 'Описание',
        'resolvedAssigneeId': 'u',
        'dueDate': '2026-12-01',
      });
      expect(server.requests.last.path, 'ai/extract-task/confirm');
      expect(server.requests.last.data, {
        'projectId': 'p',
        'title': 'Новая',
        'description': 'Описание',
        'assigneeId': 'u',
        'dueDate': '2026-12-01',
      });
    },
  );
  test('confirmation refuses a project from another workspace', () async {
    server.responses.add([
      {'id': 'p', 'workspaceId': 'other'},
    ]);
    await expectLater(
      actions.create('w', 'p', {'title': 'Новая'}),
      throwsA(isA<AssistantException>()),
    );
    expect(server.requests.length, 1);
  });
  test('changed workspace prevents a request', () async {
    await selection.save('other');
    await expectLater(
      actions.extract('w', 'Новая', [], null),
      throwsA(isA<AssistantException>()),
    );
    expect(server.requests, isEmpty);
  });
  test('edit checks old values and sends only the allowed patch', () async {
    server.responses.addAll([
      {
        'id': 't',
        'workspaceId': 'w',
        'projectId': 'p',
        'title': 'До',
        'end': null,
      },
      {},
    ]);
    await actions.apply('w', draft);
    expect(server.requests.map((e) => e.method), ['GET', 'PATCH']);
    expect(server.requests.last.data, draft['patch']);
  });
  test('stale edits never overwrite newer changes', () async {
    server.responses.add({
      'id': 't',
      'workspaceId': 'w',
      'projectId': 'p',
      'title': 'Кто-то изменил',
      'end': null,
    });
    await expectLater(
      actions.apply('w', draft),
      throwsA(isA<AssistantException>()),
    );
    expect(server.requests.length, 1);
  });
  test('task moved to another workspace cannot be patched', () async {
    server.responses.add({
      'id': 't',
      'workspaceId': 'other',
      'projectId': 'p',
      'title': 'До',
      'end': null,
    });
    await expectLater(
      actions.apply('w', draft),
      throwsA(isA<AssistantException>()),
    );
    expect(server.requests.length, 1);
  });
  test('workspace change during recheck prevents patch', () async {
    server.responses.add({
      'id': 't',
      'workspaceId': 'w',
      'projectId': 'p',
      'title': 'До',
      'end': null,
    });
    server.beforeResponse = () => selection.save('other');
    await expectLater(
      actions.apply('w', draft),
      throwsA(isA<AssistantException>()),
    );
    expect(server.requests.length, 1);
  });
  test(
    'unknown fields, invalid dates and empty titles are rejected locally',
    () async {
      for (final patch in [
        {'ownerId': 'intruder'},
        {'end': '2026-02-31'},
        {'title': '  '},
      ]) {
        await expectLater(
          actions.apply('w', {...draft, 'patch': patch}),
          throwsA(isA<AssistantException>()),
        );
      }
      expect(server.requests, isEmpty);
    },
  );
}

class _Server implements HttpClientAdapter {
  final responses = <dynamic>[];
  final requests = <RequestOptions>[];
  Future<void> Function()? beforeResponse;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await beforeResponse?.call();
    return ResponseBody.fromString(
      jsonEncode(responses.removeAt(0)),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
