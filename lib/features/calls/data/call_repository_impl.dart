import 'models/call_room_dto.dart';
import 'models/call_connection_dto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../domain/call_repository.dart';
import '../domain/entities/call_room.dart';
import '../domain/entities/call_connection.dart';

class CallRepositoryImpl implements CallRepository {
  const CallRepositoryImpl(this.dio);
  final Dio dio;
  dynamic unwrap(dynamic data) =>
      data is Map && data.containsKey('data') ? data['data'] : data;
  Future<dynamic> request(
    String method,
    String path, {
    String? workspaceId,
    Map<String, dynamic>? data,
  }) async {
    try {
      return unwrap(
        (await dio.request<dynamic>(
          'video/$path',
          data: data,
          options: Options(
            method: method,
            headers: {'X-Workspace-Id': ?workspaceId},
          ),
        )).data,
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Call request failed: method=$method, path=video/$path, '
          'status=${e.response?.statusCode}, response=${e.response?.data}',
        );
      }
      throw CallException(switch (e.response?.statusCode) {
        403 => 'Нет доступа к этому звонку.',
        404 => 'Звонок уже завершён или недоступен.',
        409 => 'Звонок уже изменился. Попробуйте ещё раз.',
        503 => 'Сервис звонков временно недоступен.',
        _ => 'Не удалось связаться с сервером звонков. Проверьте подключение.',
      });
    }
  }

  CallConnection connection(dynamic data) {
    final result = CallConnectionDto.fromJson(
      Map<String, dynamic>.from(data as Map),
    ).toEntity();
    final uri = Uri.tryParse(result.url);
    if (result.token.isEmpty ||
        uri == null ||
        !['wss', 'ws', 'https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const CallException(
        'Сервер не вернул параметры подключения к звонку.',
      );
    }
    return result;
  }

  @override
  Future<CallConnection> create({
    required String workspaceId,
    required List<String> invitees,
    required bool video,
    required String threadId,
    required String title,
  }) async => connection(
    await request(
      'POST',
      'rooms',
      workspaceId: workspaceId,
      data: {
        'workspaceId': workspaceId,
        'inviteeIds': invitees.toSet().toList(),
        'mode': video ? 'video' : 'audio',
        'threadId': threadId,
        'title': title,
      },
    ),
  );
  @override
  Future<List<CallRoom>> incoming() async {
    final data = await request('GET', 'rooms/incoming');
    return (data is List ? data : const [])
        .whereType<Map>()
        .map((e) => e['room'])
        .whereType<Map>()
        .map(
          (e) => CallRoomDto.fromJson(Map<String, dynamic>.from(e)).toEntity(),
        )
        .where(
          (e) =>
              e.id.isNotEmpty &&
              e.workspaceId.isNotEmpty &&
              e.status == 'active',
        )
        .toList();
  }

  String path(CallRoom room, String suffix) =>
      'rooms/${Uri.encodeComponent(room.id)}/$suffix';
  @override
  Future<CallConnection> join(CallRoom room) async => connection(
    await request('POST', path(room, 'join'), workspaceId: room.workspaceId),
  );
  @override
  Future<CallRoom> state(CallRoom room) async => CallRoomDto.fromJson(
    Map<String, dynamic>.from(
      await request('GET', path(room, 'state'), workspaceId: room.workspaceId)
          as Map,
    ),
  ).toEntity();
  @override
  Future<void> decline(CallRoom room) async {
    await request('POST', path(room, 'decline'), workspaceId: room.workspaceId);
  }

  @override
  Future<void> end(CallRoom room) async {
    await request(
      'POST',
      path(room, 'end'),
      workspaceId: room.workspaceId,
      data: {},
    );
  }

  @override
  Future<void> mode(CallRoom room, bool video) async {
    await request(
      'POST',
      path(room, 'mode'),
      workspaceId: room.workspaceId,
      data: {'mode': video ? 'video' : 'audio'},
    );
  }
}
