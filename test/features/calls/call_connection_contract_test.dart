import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/calls/data/call_repository_impl.dart';
import 'package:jospar/features/calls/domain/call_repository.dart';
import 'package:jospar/features/calls/domain/entities/call_room.dart';

void main() {
  late Dio dio;
  late CallRepositoryImpl repository;
  late List<RequestOptions> requests;
  dynamic response;
  setUp(() {
    dio = Dio();
    repository = CallRepositoryImpl(dio);
    requests = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.resolve(
            Response(requestOptions: request, statusCode: 200, data: response),
          );
        },
      ),
    );
  });
  tearDown(() => dio.close());
  for (final scheme in ['ws', 'wss', 'http', 'https']) {
    test('valid connection scheme $scheme remains accepted', () {
      expect(
        repository.connection({
          'token': 'jwt',
          'wsUrl': '$scheme://rtc.example',
        }).url,
        '$scheme://rtc.example',
      );
    });
  }
  for (final json in <Map<String, dynamic>>[
    {'token': '', 'wsUrl': 'wss://rtc.example'},
    {'token': 'jwt', 'wsUrl': '/relative'},
    {'token': 'jwt', 'wsUrl': 'ftp://rtc.example'},
    {'token': 'jwt', 'wsUrl': 'wss:'},
    {},
  ]) {
    test('invalid connection credentials rejected: $json', () {
      expect(() => repository.connection(json), throwsA(isA<CallException>()));
    });
  }
  test(
    'state unwraps data, preserves status, header and encoded room id',
    () async {
      response = {
        'data': {'id': 'a/b', 'workspaceId': 'w', 'status': 'RINGING'},
      };
      final room = await repository.state(
        const CallRoom(id: 'a/b', workspaceId: 'w'),
      );
      expect(room.status, 'RINGING');
      expect(requests.single.path, 'video/rooms/a%2Fb/state');
      expect(requests.single.method, 'GET');
      expect(requests.single.headers['X-Workspace-Id'], 'w');
    },
  );
  test('incoming keeps only active rooms with id and workspace', () async {
    response = {
      'data': [
        {
          'room': {'id': 'ok', 'workspaceId': 'w', 'status': 'active'},
        },
        {
          'room': {'id': 'ended', 'workspaceId': 'w', 'status': 'ended'},
        },
        {
          'room': {'id': 'upper', 'workspaceId': 'w', 'status': 'ACTIVE'},
        },
        {
          'room': {'id': '', 'workspaceId': 'w'},
        },
        {
          'room': {'id': 'missing-workspace'},
        },
        {'room': null},
        'invalid',
      ],
    };
    expect((await repository.incoming()).map((r) => r.id), ['ok']);
    expect(requests.single.path, 'video/rooms/incoming');
    expect(requests.single.method, 'GET');
    expect(requests.single.headers.containsKey('X-Workspace-Id'), isFalse);
  });
}
