import 'package:dio/dio.dart';

import '../../domain/repositories/task_details_repository.dart';
import '../models/kanban_column_model.dart';
import '../models/task_detail_model.dart';

class TaskDetailsRepositoryImpl implements TaskDetailsRepository {
  const TaskDetailsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<TaskDetailsPayload> getTask(String taskId) async {
    try {
      final response = await _dio.get<dynamic>('project-tasks/$taskId');
      return TaskDetailsPayload.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw TaskDetailsException(_messageFor(error, 'загрузить задачу'));
    } on TaskDetailsException {
      rethrow;
    } catch (_) {
      throw const TaskDetailsException('Не удалось загрузить задачу.');
    }
  }

  @override
  Future<List<TaskHistoryEntryModel>> getHistory(String taskId) async {
    try {
      final response = await _dio.get<dynamic>('project-tasks/$taskId/history');
      return _list(response.data)
          .whereType<Map>()
          .map(
            (item) =>
                TaskHistoryEntryModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw TaskDetailsException(_messageFor(error, 'загрузить историю'));
    } on TaskDetailsException {
      rethrow;
    } catch (_) {
      throw const TaskDetailsException('Не удалось загрузить историю задачи.');
    }
  }

  @override
  Future<List<KanbanColumnModel>> getColumns(String projectId) async {
    try {
      final response = await _dio.get<dynamic>(
        'kanban-columns',
        queryParameters: <String, dynamic>{'projectId': projectId},
      );
      return _list(response.data)
          .whereType<Map>()
          .map(
            (item) =>
                KanbanColumnModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((column) => column.id.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      throw TaskDetailsException(_messageFor(error, 'загрузить колонки'));
    } on TaskDetailsException {
      rethrow;
    } catch (_) {
      throw const TaskDetailsException('Не удалось загрузить колонки.');
    }
  }

  @override
  Future<TaskDetailsPayload> updateProgress(String taskId, int progress) {
    return _patch(taskId, <String, dynamic>{'progress': progress});
  }

  @override
  Future<TaskDetailsPayload> updateDetail(
    String taskId,
    TaskDetailModel detail,
  ) {
    return _patch(taskId, <String, dynamic>{'detail': detail.toJson()});
  }

  @override
  Future<TaskDetailsPayload> updateEnd(String taskId, DateTime? end) {
    return _patch(taskId, <String, dynamic>{
      'end': end?.toUtc().toIso8601String(),
    });
  }

  Future<TaskDetailsPayload> _patch(
    String taskId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch<dynamic>(
        'project-tasks/$taskId',
        data: data,
      );
      return TaskDetailsPayload.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw TaskDetailsException(_messageFor(error, 'сохранить изменения'));
    } on TaskDetailsException {
      rethrow;
    } catch (_) {
      throw const TaskDetailsException('Не удалось сохранить изменения.');
    }
  }

  Map<String, dynamic> _object(dynamic data) {
    if (data is! Map) {
      throw const TaskDetailsException('Сервер вернул некорректную задачу.');
    }
    final payload = Map<String, dynamic>.from(data);
    final nested = payload['data'];
    return nested is Map ? Map<String, dynamic>.from(nested) : payload;
  }

  List<dynamic> _list(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final payload = Map<String, dynamic>.from(data);
      for (final key in const <String>['data', 'history', 'items', 'columns']) {
        final value = payload[key];
        if (value is List) return value;
      }
    }
    throw const TaskDetailsException('Сервер вернул некорректный список.');
  }

  String _messageFor(DioException error, String action) {
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
        if (code == 404) return 'Задача не найдена.';
        return 'Не удалось $action.';
      case DioExceptionType.cancel:
        return 'Запрос был отменён.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return 'Не удалось подключиться к серверу.';
    }
  }
}
