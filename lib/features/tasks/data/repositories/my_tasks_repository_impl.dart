import 'package:dio/dio.dart';

import '../../../projects/data/models/project_task_model.dart';
import '../../domain/repositories/my_tasks_repository.dart';
import '../models/kanban_column_model.dart';

class MyTasksRepositoryImpl implements MyTasksRepository {
  const MyTasksRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<ProjectTaskModel>> getTasks({
    required String assigneeId,
    List<String> projectIds = const <String>[],
  }) async {
    try {
      final ids = projectIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final response = await _dio.get<dynamic>(
        'project-tasks',
        queryParameters: <String, dynamic>{
          'assigneeId': assigneeId,
          if (ids.isNotEmpty) 'projectIds': ids.join(','),
        },
      );
      return _unwrapList(response.data)
          .whereType<Map>()
          .map(
            (item) =>
                ProjectTaskModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((task) => task.id.isNotEmpty && task.projectId.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      throw MyTasksException(_messageFor(error, action: 'загрузить задачи'));
    } on MyTasksException {
      rethrow;
    } catch (_) {
      throw const MyTasksException('Не удалось загрузить задачи.');
    }
  }

  @override
  Future<List<KanbanColumnModel>> getKanbanColumns(String projectId) async {
    try {
      final response = await _dio.get<dynamic>(
        'kanban-columns',
        queryParameters: <String, dynamic>{'projectId': projectId},
      );
      return _unwrapList(response.data)
          .whereType<Map>()
          .map(
            (item) =>
                KanbanColumnModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((column) => column.id.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      throw MyTasksException(_messageFor(error, action: 'загрузить колонки'));
    } on MyTasksException {
      rethrow;
    } catch (_) {
      throw const MyTasksException('Не удалось загрузить колонки проектов.');
    }
  }

  @override
  Future<void> updateProgress(String taskId, int progress) async {
    try {
      await _dio.patch<dynamic>(
        'project-tasks/$taskId',
        data: <String, dynamic>{'progress': progress},
      );
    } on DioException catch (error) {
      throw MyTasksException(_messageFor(error, action: 'обновить задачу'));
    } catch (_) {
      throw const MyTasksException('Не удалось обновить задачу.');
    }
  }

  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final payload = Map<String, dynamic>.from(data);
      for (final key in const <String>['data', 'tasks', 'columns', 'items']) {
        final value = payload[key];
        if (value is List) return value;
        if (value is Map) {
          final nested = Map<String, dynamic>.from(value);
          for (final nestedKey in const <String>['tasks', 'columns', 'items']) {
            final nestedValue = nested[nestedKey];
            if (nestedValue is List) return nestedValue;
          }
        }
      }
    }
    throw const MyTasksException('Сервер вернул некорректные данные.');
  }

  String _messageFor(DioException error, {required String action}) {
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
        return 'Не удалось $action.';
      case DioExceptionType.cancel:
        return 'Запрос был отменён.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return 'Не удалось подключиться к серверу.';
    }
  }
}

class MyTasksException implements Exception {
  const MyTasksException(this.message);

  final String message;

  @override
  String toString() => message;
}
