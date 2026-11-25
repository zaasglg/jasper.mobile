import '../../domain/entities/assistant_request.dart';
import '../services/assistant_cancel_token.dart';
import '../services/assistant_api_errors.dart';
import 'dart:convert';
import '../../domain/entities/assistant_attachment.dart';
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
    List<AssistantAttachment> attachments = const [],
    String? currentProjectId,
    AssistantRequest? request,
  }) async {
    try {
      if (attachments.length + images.length > 3) {
        throw const AssistantException('Можно прикрепить до 3 файлов.');
      }
      final payload = {
        'workspaceId': workspaceId,
        'currentProjectId': ?currentProjectId,
        if (images.isNotEmpty) 'images': images,
        if (attachments.isNotEmpty)
          'attachments': attachments.map((e) => e.toUploadJson()).toList(),
        'messages': messages
            .map((e) => {'role': e.role, 'content': e.content})
            .toList(),
      };
      if (messages.length > 100 ||
          messages.fold<int>(0, (sum, m) => sum + m.content.length) > 100000) {
        throw const AssistantException(
          'История слишком большая. Начните новый диалог.',
        );
      }
      if (utf8.encode(jsonEncode(payload)).length > 35651584) {
        throw const AssistantException(
          'Запрос слишком большой. Удалите часть вложений или начните новый диалог.',
        );
      }
      final response = await _dio.post<dynamic>(
        'ai/assistant/chat',
        cancelToken: assistantCancelToken(request),
        options: Options(
          headers: {'X-Workspace-Id': workspaceId},
          receiveTimeout: const Duration(minutes: 4),
          sendTimeout: const Duration(minutes: 2),
        ),
        data: payload,
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
      if (attachments.isNotEmpty &&
          AssistantAttachment.parseList(json['attachments']).length !=
              attachments.length + images.length) {
        throw const AssistantException(
          'Не удалось подтвердить чтение файлов. Повторите запрос позже.',
        );
      }
      return AssistantMessageDto.fromJson({
        ...Map<String, dynamic>.from(json),
        'role': 'assistant',
      }).toEntity();
    } on DioException catch (error) {
      throw AssistantException(assistantApiError(error));
    }
  }
}
