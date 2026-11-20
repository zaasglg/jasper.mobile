import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/network/api_constants.dart';
import 'package:jospar/core/widgets/user_avatar.dart';
import 'package:jospar/features/calls/data/models/call_room_dto.dart';
import 'package:jospar/features/calls/data/models/call_connection_dto.dart';
import 'package:jospar/features/calls/domain/entities/call_room.dart';
import 'package:jospar/features/calls/domain/entities/call_connection.dart';

void main() {
  test('room DTO serialization and conversions preserve every field', () {
    const room = CallRoom(
      id: 'r',
      workspaceId: 'w',
      mode: 'video',
      title: 'Title',
      callerName: 'Caller',
      callerId: 'u',
      callerAvatar: 'https://cdn/x.png',
      threadId: 'thread',
      status: 'ringing',
      createdById: 'creator',
      endOnHangup: true,
      canInvite: true,
    );
    final dto = CallRoomDto.fromEntity(room);
    expect(dto.toJson(), {
      'id': 'r',
      'workspaceId': 'w',
      'mode': 'video',
      'title': 'Title',
      'callerName': 'Caller',
      'callerId': 'u',
      'callerAvatar': 'https://cdn/x.png',
      'threadId': 'thread',
      'status': 'ringing',
      'createdById': 'creator',
      'endOnHangup': true,
      'canInvite': true,
    });
    expect(dto.toEntity(), room);
    expect(CallRoomDto.fromJson(dto.toJson()), dto);
    expect(dto.copyWith(title: 'Other').callerId, 'u');
    expect(room.copyWith(title: 'Other').status, 'ringing');
    expect(room.video, isTrue);
  });
  for (final mode in <Object?>[
    'video',
    'audio',
    'VIDEO',
    'unknown',
    null,
    123,
  ]) {
    test('mode $mode is video only for exact video string', () {
      final entity = CallRoomDto.fromJson({'mode': mode}).toEntity();
      expect(entity.mode, mode == 'video' ? 'video' : 'audio');
      expect(entity.video, mode == 'video');
    });
  }
  for (final status in ['active', 'ended', 'ringing', 'ACTIVE', '', 'custom']) {
    test('status is preserved exactly: $status', () {
      expect(
        CallRoomDto.fromJson({'status': status}).toEntity().status,
        status,
      );
    });
  }
  test('room missing/null fields preserve defaults and scalar coercion', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {'id': null, 'workspaceId': null, 'status': null},
    ]) {
      expect(
        CallRoomDto.fromJson(json).toEntity(),
        const CallRoom(id: '', workspaceId: ''),
      );
    }
    final room = CallRoomDto.fromJson({
      'id': 123,
      'workspaceId': {'w': 1},
      'status': 42,
      'title': ['x'],
      'createdById': false,
      'endOnHangup': 'true',
      'canInvite': 1,
    }).toEntity();
    expect(room.id, '123');
    expect(room.workspaceId, '{w: 1}');
    expect(room.status, '42');
    expect(room.title, '[x]');
    expect(room.createdById, 'false');
    expect(room.endOnHangup, isFalse);
    expect(room.canInvite, isFalse);
  });
  test('createdBy fields override flat fields with null fallback', () {
    final room = CallRoomDto.fromJson({
      'callerName': 'Flat',
      'callerId': 'flat',
      'callerAvatar': 'https://cdn/flat.png',
      'createdBy': {'name': '', 'id': 123, 'avatarUrl': null},
    }).toEntity();
    expect(room.callerName, '');
    expect(room.callerId, '123');
    expect(room.callerAvatar, 'https://cdn/flat.png');
    expect(
      CallRoomDto.fromJson({
        'createdBy': 'invalid',
        'callerName': 'Flat',
      }).callerName,
      'Flat',
    );
  });
  for (final avatar in [
    'https://cdn/x.png',
    '/avatar.png',
    'data:image/png;base64,...',
  ]) {
    test('caller avatar DTO → entity → UI resolver is stable: $avatar', () {
      final expected = avatar.startsWith('/')
          ? ApiConstants.origin.resolve(avatar).toString()
          : avatar;
      for (final json in [
        {'callerAvatar': avatar},
        {
          'createdBy': {'avatarUrl': avatar},
        },
      ]) {
        final room = CallRoomDto.fromJson(json).toEntity();
        expect(room.callerAvatar, expected);
        expect(resolveUserAvatarUrl(room.callerAvatar), expected);
      }
    });
  }
  test('avatar coercion and invalid URL handling match UI resolver', () {
    for (final avatar in <Object?>[null, '', '  ', 123, 'ftp://host/a']) {
      final room = CallRoomDto.fromJson({'callerAvatar': avatar}).toEntity();
      expect(room.callerAvatar, resolveUserAvatarUrl(avatar?.toString()));
    }
    expect(
      const CallRoom(
        id: 'r',
        workspaceId: 'w',
        callerAvatar: '/raw',
      ).callerAvatar,
      '/raw',
    );
  });
  test(
    'connection maps wsUrl, nested room and converts in both directions',
    () {
      const room = CallRoom(id: 'r', workspaceId: 'w', mode: 'video');
      const entity = CallConnection(
        token: 'jwt',
        url: 'wss://rtc.example',
        room: room,
      );
      final dto = CallConnectionDto.fromEntity(entity);
      expect(dto.toJson(), {
        'token': 'jwt',
        'wsUrl': 'wss://rtc.example',
        'room': CallRoomDto.fromEntity(room).toJson(),
      });
      expect(dto.toEntity(), entity);
      expect(CallConnectionDto.fromJson(dto.toJson()), dto);
      expect(dto.copyWith(token: 'other').room, dto.room);
      expect(entity.copyWith(token: 'other').room, room);
    },
  );
  test('connection missing/null/invalid nested room and token coercion', () {
    for (final invalid in <Object?>[null, 'invalid', [], 123]) {
      expect(
        CallConnectionDto.fromJson({'room': invalid}).toEntity(),
        const CallConnection(token: '', url: ''),
      );
    }
    final dto = CallConnectionDto.fromJson({
      'token': 123,
      'wsUrl': {'x': 1},
      'room': {},
    });
    expect(dto.token, '123');
    expect(dto.url, '{x: 1}');
    expect(dto.room?.toEntity(), const CallRoom(id: '', workspaceId: ''));
    expect(
      const CallConnectionDto(token: '', url: '').toJson().containsKey('room'),
      isFalse,
    );
    expect(const CallConnectionDto(token: '', url: '').toEntity().room, isNull);
  });
}
