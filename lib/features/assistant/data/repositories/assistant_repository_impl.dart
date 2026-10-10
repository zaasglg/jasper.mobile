import 'package:dio/dio.dart';
import '../../domain/repositories/assistant_repository.dart';
import '../models/assistant_message_model.dart';

class AssistantRepositoryImpl implements AssistantRepository {
  const AssistantRepositoryImpl(this._dio);
  final Dio _dio;
  @override
  Future<AssistantMessageModel> chat({
    required String workspaceId,
    required List<AssistantMessageModel> messages,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        'ai/assistant/chat',
        data: {
          'workspaceId': workspaceId,
          'messages': messages.map((e) => e.toJson()).toList(),
        },
      );
      final body = response.data;
      final json = body is Map && body['data'] is Map
          ? body['data'] as Map
          : body;
      if (json is! Map ||
          json['content'] is! String ||
          (json['content'] as String).trim().isEmpty) {
        throw const AssistantException(
          'Помощник вернул пустой ответ. Попробуйте ещё раз.',
        );
      }
      return AssistantMessageModel(
        role: 'assistant',
        content: json['content'] as String,
      );
    } on DioException catch (error) {
      throw AssistantException(
        error.response?.statusCode == 403
            ? 'В этом пространстве нет доступа к ИИ-помощнику.'
            : error.type == DioExceptionType.connectionError
            ? 'Нет подключения к интернету.'
            : 'Не удалось получить ответ. Попробуйте ещё раз.',
      );
    }
  }
}
