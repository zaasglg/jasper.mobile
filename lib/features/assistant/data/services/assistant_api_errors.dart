import 'package:dio/dio.dart';

String assistantApiError(Object error) {
  if (error is! DioException) return 'Не удалось получить ответ.';
  final raw = error.response?.data;
  final body = raw is Map && raw['data'] is Map ? raw['data'] as Map : raw;
  if (body is Map) {
    final code = body['code']?.toString() ?? '';
    if (code.startsWith('ATTACHMENT_') ||
        const {
          'WORKSPACE_MISMATCH',
          'WORKSPACE_REQUIRED',
          'MESSAGE_TOO_LARGE',
          'REQUEST_TOO_LARGE',
          'REQUEST_INVALID',
          'CONTENT_TYPE_UNSUPPORTED',
          'REQUEST_ENCODING_UNSUPPORTED',
          'AI_UNAVAILABLE',
        }.contains(code) ||
        error.response?.statusCode == 400) {
      final message = body['message'];
      if (message is String && message.trim().isNotEmpty) return message;
      if (message is List) {
        final messages = message.whereType<String>().take(3).join('\n');
        if (messages.isNotEmpty) return messages;
      }
    }
  }
  return switch (error.response?.statusCode) {
    401 => 'Сессия истекла. Войдите в приложение заново.',
    403 => 'В этом пространстве нет доступа к ИИ-помощнику.',
    404 => 'Проект или задача больше недоступны.',
    413 => 'Файлы или история переписки слишком большие.',
    429 => 'Предыдущие файлы ещё обрабатываются. Повторите запрос позже.',
    503 => 'ИИ временно недоступен. Повторите запрос позже.',
    504 => 'Обработка заняла слишком много времени. Повторите запрос позже.',
    _ =>
      error.type == DioExceptionType.connectionError
          ? 'Нет подключения к интернету.'
          : error.type == DioExceptionType.receiveTimeout ||
                error.type == DioExceptionType.sendTimeout
          ? 'Время ожидания истекло. Повторите запрос вручную.'
          : 'Не удалось получить ответ. Попробуйте ещё раз.',
  };
}
