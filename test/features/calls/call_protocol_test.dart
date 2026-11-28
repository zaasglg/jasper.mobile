import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/calls/data/call_protocol_repository_impl.dart';
import 'package:jospar/features/calls/domain/call_media.dart';
import 'package:jospar/features/calls/domain/call_protocol_repository.dart';
import 'package:jospar/features/calls/domain/call_repository.dart';
import 'package:jospar/features/calls/domain/entities/call_room.dart';
import 'package:jospar/features/calls/presentation/protocol/call_protocol_cubit.dart';
import 'package:jospar/features/calls/presentation/protocol/call_protocol_screen.dart';

const room = CallRoom(id: 'r', workspaceId: 'w', title: 'Совещание');
Future<void> settle() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'uses web summary endpoints, workspace header and exact envelope',
    () async {
      final adapter = _Adapter();
      final repo = CallProtocolRepositoryImpl(
        Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
          ..httpClientAdapter = adapter,
      );
      final content = {
        'documentNumber': '2026-R',
        'duration': '00:05:00',
        'participantIds': ['me'],
        'allEntries': [
          {'id': '1', 'text': 'Решение', 'kind': 'chat'},
        ],
      };
      await repo.save(room, content);
      expect(adapter.requests.map((e) => e.path), [
        'video/rooms/r/summary/generate',
        'video/rooms/r/summaries',
      ]);
      expect(adapter.requests.last.data, {
        'documentNumber': '2026-R',
        'duration': '00:05:00',
        'participantCount': 1,
        'content': content,
      });
      expect(
        adapter.requests.every((e) => e.headers['X-Workspace-Id'] == 'w'),
        isTrue,
      );
      await repo.versions(room, 20);
      expect(adapter.requests.last.queryParameters, {'skip': 20, 'take': 20});
      adapter.status = 403;
      await expectLater(
        repo.save(room, content),
        throwsA(isA<CallException>()),
      );
      expect(
        adapter.requests.where((e) => e.path.endsWith('/summaries')).length,
        2,
      );
    },
  );
  test(
    'captures web speech and idless chat, ignores duplicates and malformed packets',
    () async {
      final media = _Media();
      final repo = _Repository();
      final cubit = CallProtocolCubit(repo, media);
      addTearDown(() async {
        await cubit.close();
        media.dispose();
      });
      cubit.begin(room, DateTime.now());
      await settle();
      media.events.add({
        'type': 'chat',
        'userId': 'peer',
        'text': 'Обсудить бюджет',
        'timestamp': '00:00:01',
      });
      media.events.add({
        'type': 'speech',
        'id': 's1',
        'userId': 'peer',
        'text': 'Готово',
        'timestamp': '00:00:02',
      });
      media.events.add({'type': 'speech', 'id': 's1', 'text': 'Дубль'});
      media.events.add({'type': 'speech', 'id': 4, 'text': []});
      await settle();
      expect(cubit.state.entries.length, 2);
      expect(cubit.state.entries.last.kind, 'speech');
      await cubit.toggleDecision(cubit.state.entries.last);
      expect(media.sent.last['type'], 'key-decision');
      cubit.end();
      media.identity = '';
      expect(await cubit.addNote('Итог встречи'), isTrue);
      expect(cubit.state.entries.last.userId, 'me');
      await cubit.save();
      expect(repo.saved!['speechCount'], 1);
      expect(repo.saved!['chatCount'], 2);
      expect((repo.saved!['keyDecisions'] as List).length, 1);
      expect(repo.saved!['participantIds'], containsAll(['me', 'peer']));
      expect(cubit.state.document, isNotNull);
      media.events.add({'type': 'speech', 'id': 'late', 'text': 'late'});
      await settle();
      expect(cubit.state.entries.length, 3);
    },
  );
  test(
    'permission denial and failed save retain draft; stale account replies ignored',
    () async {
      final media = _Media();
      final repo = _Repository();
      final cubit = CallProtocolCubit(repo, media);
      addTearDown(() async {
        await cubit.close();
        media.dispose();
      });
      cubit.begin(room, DateTime.now());
      await settle();
      await cubit.addNote('Не потерять');
      repo.failure = true;
      await cubit.save();
      expect(cubit.state.entries.single.text, 'Не потерять');
      expect(cubit.state.error, isNotNull);
      repo.failure = false;
      repo.allowed = false;
      await cubit.refresh();
      await cubit.save();
      expect(repo.saves, 1);
      repo.pending = Completer<Map<String, dynamic>>();
      final refresh = cubit.refreshAccess();
      cubit.clear();
      repo.pending!.complete({'canGenerate': true});
      await refresh;
      expect(cubit.state.room, isNull);
      expect(cubit.state.access, isEmpty);
    },
  );
  testWidgets(
    'protocol fits compact dark screen with large text and adds a note',
    (tester) async {
      final media = _Media();
      final repo = _Repository();
      final cubit = CallProtocolCubit(repo, media);
      addTearDown(() async {
        await cubit.close();
        media.dispose();
      });
      cubit.begin(room, DateTime.now());
      await tester.runAsync(settle);
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
            child: CallProtocolScreen(cubit: cubit),
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.byType(TextField), 150);
      await tester.enterText(find.byType(TextField), 'Итог');
      await tester.ensureVisible(find.text('Добавить заметку'));
      await tester.tap(find.text('Добавить заметку'));
      await tester.pump();
      expect(cubit.state.entries.single.text, 'Итог');
      expect(tester.takeException(), isNull);
      cubit.end();
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _Media extends CallMedia {
  final events = StreamController<Map<String, dynamic>>.broadcast();
  final sent = <Map<String, dynamic>>[];
  String identity = 'me';
  @override
  Stream<Map<String, dynamic>> get protocolEvents => events.stream;
  @override
  String get localIdentity => identity;
  @override
  Map<String, String> get protocolParticipants => {
    'me': 'Я',
    'peer': 'Коллега',
  };
  @override
  Future<void> publishProtocol(Map<String, dynamic> message) async {
    sent.add(message);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  void dispose() {
    unawaited(events.close());
    super.dispose();
  }
}

class _Repository implements CallProtocolRepository {
  bool failure = false, allowed = true;
  int saves = 0;
  Map<String, dynamic>? saved;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> access(CallRoom room) async =>
      pending != null ? pending!.future : {'canGenerate': allowed};
  @override
  Future<Map<String, dynamic>> grant(
    CallRoom room,
    String id,
    bool enabled,
  ) async => {};
  @override
  Future<Map<String, dynamic>> versions(CallRoom room, int skip) async => {
    'items': [],
    'total': 0,
  };
  @override
  Future<Map<String, dynamic>> version(CallRoom room, String id) async => {
    'content': saved,
  };
  @override
  Future<Map<String, dynamic>> save(
    CallRoom room,
    Map<String, dynamic> content,
  ) async {
    saves++;
    if (failure) throw const CallException('Сбой');
    saved = content;
    return {'id': 'v', 'content': content};
  }
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'allowed': true}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
