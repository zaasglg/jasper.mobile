import 'package:dio/dio.dart';
import '../../domain/repositories/assistant_repository.dart';
import '../../domain/entities/assistant_message_model.dart';
import '../models/assistant_message_dto.dart';

class AssistantRepositoryImpl implements AssistantRepository {
  const AssistantRepositoryImpl(this._dio);
  final Dio _dio;
  @override
  Future<AssistantMessageModel> chat({
    required String workspaceId,
    required List<AssistantMessageModel> messages,
    List<String> images = const [],
    String? currentProjectId,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        'ai/assistant/chat',
        options: Options(headers: {'X-Workspace-Id': workspaceId}),
        data: {
          'workspaceId': workspaceId,
          'currentProjectId': ?currentProjectId,
          if (images.isNotEmpty) 'images': images,
          'messages': messages
              .map((e) => {'role': e.role, 'content': e.content})
              .toList(),
        },
      );
      final body = response.data;
      final json = body is Map && body['data'] is Map
          ? body['data'] as Map
          : body;
      if (json is! Map ||
          ((json['content'] is! String ||
                  (json['content'] as String).trim().isEmpty) &&
              (json['toolCalls'] is! List ||
                  (json['toolCalls'] as List).isEmpty))) {
        throw const AssistantException(
          'Помощник вернул пустой ответ. Попробуйте ещё раз.',
        );
      }
      return AssistantMessageDto.fromJson({
        ...Map<String, dynamic>.from(json),
        'role': 'assistant',
      }).toEntity();
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
