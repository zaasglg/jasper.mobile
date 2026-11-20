import 'package:jospar/features/calls/data/models/call_room_dto.dart';
import 'package:jospar/features/calls/data/models/call_connection_dto.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/calls/domain/entities/call_room.dart';
import 'package:jospar/features/calls/data/call_repository_impl.dart';
import 'package:jospar/features/calls/domain/call_repository.dart';

void main() {
  late _Adapter server;
  late CallRepositoryImpl repo;
  const room = CallRoom(id: 'room', workspaceId: 'workspace', mode: 'video');
  setUp(() {
    server = _Adapter();
    repo = CallRepositoryImpl(
      Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
        ..httpClientAdapter = server,
    );
  });
  test(
    'creates same livekit room as website with unique invitees and workspace header',
    () async {
      server.reply = {
        'room': CallRoomDto.fromEntity(room).toJson(),
        'token': 'jwt',
        'wsUrl': 'wss://rtc.example',
      };
      final result = await repo.create(
        workspaceId: 'workspace',
        invitees: ['user', 'user'],
        video: true,
        threadId: 'dm:me:user',
        title: 'Тест',
      );
      expect(server.request!.path, 'video/rooms');
      expect(server.request!.data, {
        'workspaceId': 'workspace',
        'inviteeIds': ['user'],
        'mode': 'video',
        'threadId': 'dm:me:user',
        'title': 'Тест',
      });
      expect(server.request!.headers['X-Workspace-Id'], 'workspace');
      expect(result.room!.id, 'room');
      expect(
        CallConnectionDto.fromJson(
          CallConnectionDto.fromEntity(result).toJson(),
        ).toEntity(),
        result,
      );
    },
  );
  test('incoming parses room and avatar rather than invite id', () async {
    server.reply = [
      {
        'id': 'invite',
        'room': {
          ...CallRoomDto.fromEntity(room).toJson(),
          'createdBy': {
            'id': 'user',
            'name': 'Коллега',
            'avatarUrl': 'https://example.test/avatar.png',
          },
        },
      },
    ];
    final incoming = await repo.incoming();
    expect(incoming.single.id, 'room');
    expect(incoming.single.callerName, 'Коллега');
    expect(incoming.single.callerAvatar, 'https://example.test/avatar.png');
    expect(
      CallRoomDto.fromJson(
        CallRoomDto.fromEntity(incoming.single).toJson(),
      ).toEntity(),
      incoming.single,
    );
  });
  test('join, reject, mode and hangup use website endpoints', () async {
    server.reply = {'token': 'jwt', 'wsUrl': 'wss://rtc.example'};
    await repo.join(room);
    expect(server.request!.path, 'video/rooms/room/join');
    expect(server.request!.method, 'POST');
    server.reply = {};
    await repo.decline(room);
    expect(server.request!.path, 'video/rooms/room/decline');
    await repo.mode(room, true);
    expect(server.request!.path, 'video/rooms/room/mode');
    expect(server.request!.data, {'mode': 'video'});
    await repo.end(room);
    expect(server.request!.path, 'video/rooms/room/end');
  });
  test('invalid media credentials are rejected before connecting', () async {
    server.reply = {'token': '', 'wsUrl': 'https://rtc.example'};
    await expectLater(repo.join(room), throwsA(isA<CallException>()));
  });
  test('server permission failure becomes a readable error', () async {
    server.status = 403;
    server.reply = {};
    await expectLater(
      repo.join(room),
      throwsA(
        isA<CallException>().having(
          (e) => e.message,
          'message',
          contains('Нет доступа'),
        ),
      ),
    );
  });
}

class _Adapter implements HttpClientAdapter {
  RequestOptions? request;
  dynamic reply;
  int status = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(reply),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
