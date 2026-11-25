import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/activity/data/activity_repository.dart';

void main() {
  test('call events show a heading rather than their transport JSON', () {
    for (final mode in ['audio', 'video']) {
      final payload = jsonEncode({
        'callId': 'call',
        'mode': mode,
        'status': 'ended',
        'createdById': 'user',
        'title': 'Private <b>&quot;call metadata&quot;</b>',
      });
      for (final nested in [false, true]) {
        final message = {'threadId': 'dm:a:b', 'kind': 'CALL', 'text': payload};
        final entry = ActivityEntry.fromJson({
          'id': 'event',
          if (nested) 'message': message else ...message,
        });
        expect(
          entry.text,
          mode == 'video' ? 'Видеозвонок завершён' : 'Звонок завершён',
        );
        expect(entry.threadId, 'dm:a:b');
        expect(entry.text, isNot(contains('callId')));
        expect(entry.text, isNot(contains('createdById')));
      }
    }
  });

  test('legacy calls and malformed typed calls do not leak raw payloads', () {
    expect(
      ActivityEntry.fromJson({
        'text': jsonEncode({
          'callId': 'legacy',
          'mode': 'video',
          'status': 'ended',
        }),
      }).text,
      'Видеозвонок завершён',
    );
    expect(
      ActivityEntry.fromJson({'kind': 'CALL', 'text': '{broken payload'}).text,
      'Звонок',
    );
  });

  test('ordinary JSON and quoted user text remain readable user content', () {
    for (final text in [
      '{"answer":42}',
      '↩ @Автор: «Видеозвонок завершён»\n\nПривет',
      '<p>Привет</p>',
    ]) {
      final entry = ActivityEntry.fromJson({'text': text});
      expect(entry.text, text == '<p>Привет</p>' ? 'Привет' : text);
    }
  });
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'selected_workspace_id': 'w',
    }),
  );
  test(
    'mentions and reactions preserve the correct task and thread targets',
    () async {
      final adapter = _ActivityAdapter();
      final repo = ActivityRepository(
        Dio()..httpClientAdapter = adapter,
        const WorkspaceSelectionStorage(FlutterSecureStorage()),
      );
      final entries = await repo.load(ActivityKind.mentions);
      expect(entries.map((e) => e.id), ['reaction:r', 'mention:m']);
      expect(entries.first.threadId, 'dm:u:v');
      expect(entries.last.taskId, 't');
      expect(entries.last.text, 'Название & текст');
    },
  );
  test(
    'saved messages use a paginated favorites endpoint without scanning unrelated threads',
    () async {
      final adapter = _ActivityAdapter();
      final repo = ActivityRepository(
        Dio()..httpClientAdapter = adapter,
        const WorkspaceSelectionStorage(FlutterSecureStorage()),
      );
      final entries = await repo.load(ActivityKind.saved);
      expect(entries.map((e) => e.id), ['a', 'b']);
      expect(
        adapter.requests.every((e) => e.path == 'messages/favorites'),
        true,
      );
      expect(adapter.requests.last.queryParameters['cursor'], 'older');
      expect(adapter.requests.last.queryParameters['workspaceId'], 'w');
    },
  );
  test('notification direct messages respect server unread counts', () async {
    final adapter = _ActivityAdapter();
    final repo = ActivityRepository(
      Dio()..httpClientAdapter = adapter,
      const WorkspaceSelectionStorage(FlutterSecureStorage()),
    );
    final entries = await repo.load(ActivityKind.notifications);
    expect(entries.where((e) => e.text == 'Непрочитанное').length, 1);
    expect(entries.where((e) => e.text == 'Прочитанное'), isEmpty);
  });
}

class _ActivityAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    final Object data = switch (options.path) {
      'dashboard/mentions' => [
        {
          'id': 'm',
          'taskId': 't',
          'text': '<p>Название &amp; текст</p>',
          'createdAt': '2026-10-29',
          'user': {'name': 'Автор'},
        },
      ],
      'dashboard/reactions' => [
        {
          'id': 'r',
          'emoji': '👍',
          'createdAt': '2026-10-30',
          'message': {'threadId': 'dm:u:v', 'text': 'Текст'},
        },
      ],
      'messages/favorites' => {
        'data': [
          {
            'id': options.queryParameters['cursor'] == null ? 'a' : 'b',
            'text': 'Сообщение',
            'threadId': 'channel',
          },
        ],
        'nextCursor': options.queryParameters['cursor'] == null
            ? 'older'
            : null,
      },
      'messages/threads' => [
        {'threadId': 'dm:u:v', 'text': 'Непрочитанное'},
        {'threadId': 'dm:u:x', 'text': 'Прочитанное'},
      ],
      'messages/unread-per-thread' => {
        'counts': {'dm:u:v': 2, 'dm:u:x': 0},
      },
      _ => [],
    };
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
