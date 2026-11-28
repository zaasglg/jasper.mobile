import 'package:dio/dio.dart';
import '../domain/call_protocol_repository.dart';
import '../domain/call_repository.dart';
import '../domain/entities/call_room.dart';

class CallProtocolRepositoryImpl implements CallProtocolRepository {
  const CallProtocolRepositoryImpl(this.dio);
  final Dio dio;
  String _path(CallRoom room) => 'video/rooms/${Uri.encodeComponent(room.id)}';
  Future<Map<String, dynamic>> _request(
    CallRoom room,
    String method,
    String suffix, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await dio.request<dynamic>(
        '${_path(room)}/$suffix',
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {'X-Workspace-Id': room.workspaceId},
        ),
      );
      final raw = response.data;
      final body = raw is Map && raw['data'] is Map ? raw['data'] : raw;
      if (body is! Map) {
        throw const CallException('Некорректный ответ сервера.');
      }
      return Map<String, dynamic>.from(body);
    } on DioException catch (e) {
      throw CallException(switch (e.response?.statusCode) {
        403 => 'Нет доступа к протоколу звонка.',
        404 => 'Протокол звонка недоступен.',
        400 => 'Нет новых записей для протокола.',
        _ => 'Не удалось загрузить или сохранить протокол. Попробуйте ещё раз.',
      });
    }
  }

  @override
  Future<Map<String, dynamic>> access(CallRoom room) =>
      _request(room, 'GET', 'summary-access');
  @override
  Future<Map<String, dynamic>> grant(
    CallRoom room,
    String userId,
    bool enabled,
  ) => _request(
    room,
    'PUT',
    'summary-access',
    data: {'userId': userId, 'enabled': enabled},
  );
  @override
  Future<Map<String, dynamic>> versions(CallRoom room, int skip) =>
      _request(room, 'GET', 'summaries', query: {'skip': skip, 'take': 20});
  @override
  Future<Map<String, dynamic>> version(CallRoom room, String id) =>
      _request(room, 'GET', 'summaries/${Uri.encodeComponent(id)}');
  @override
  Future<Map<String, dynamic>> save(
    CallRoom room,
    Map<String, dynamic> content,
  ) async {
    await _request(room, 'POST', 'summary/generate');
    return _request(
      room,
      'POST',
      'summaries',
      data: {
        'documentNumber': content['documentNumber'],
        'duration': content['duration'],
        'participantCount': (content['participantIds'] as List).length,
        'content': content,
      },
    );
  }
}
