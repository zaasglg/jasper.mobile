import 'package:dio/dio.dart';

import '../../domain/repositories/inbox_repository.dart';
import '../models/inbox_task_model.dart';

class InboxRepositoryImpl implements InboxRepository {
  const InboxRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<InboxTaskModel>> getInbox({
    bool archived = true,
    int sort = 1,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'inbox',
        queryParameters: <String, dynamic>{
          'archived': archived ? 1 : 0,
          'sort': sort,
        },
      );
      return _unwrapList(response.data)
          .whereType<Map>()
          .map(
            (item) => InboxTaskModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((task) => task.id.isNotEmpty && task.title.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      throw InboxException(_messageFor(error));
    } on InboxException {
      rethrow;
    } catch (_) {
      throw const InboxException('Не удалось загрузить задачи Инбокса.');
    }
  }

  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final payload = Map<String, dynamic>.from(data);
      for (final key in const <String>[
        'data',
        'inbox',
        'tasks',
        'items',
        'rows',
        'results',
      ]) {
        final value = payload[key];
        if (value is List) return value;
        if (value is Map) {
          final nested = Map<String, dynamic>.from(value);
          for (final nestedKey in const <String>[
            'inbox',
            'tasks',
            'items',
            'rows',
            'results',
          ]) {
            final nestedValue = nested[nestedKey];
            if (nestedValue is List) return nestedValue;
          }
        }
      }
    }
    throw const InboxException('Сервер вернул некорректный список Инбокса.');
  }

  String _messageFor(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return 'Сервер не отвечает. Попробуйте ещё раз.';
      case DioExceptionType.connectionError:
        return 'Нет подключения к интернету.';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 401 || code == 403) {
          return 'Сессия истекла. Войдите снова.';
        }
        return 'Не удалось загрузить задачи Инбокса.';
      case DioExceptionType.cancel:
        return 'Запрос был отменён.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return 'Не удалось подключиться к серверу.';
    }
  }
}

class InboxException implements Exception {
  const InboxException(this.message);

  final String message;

  @override
  String toString() => message;
}
