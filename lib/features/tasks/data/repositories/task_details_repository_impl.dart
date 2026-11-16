import '../models/task_label_catalog.dart';
import 'package:dio/dio.dart';

import '../../domain/repositories/task_details_repository.dart';
import '../models/kanban_column_model.dart';
import '../models/task_detail_model.dart';
import '../../../projects/data/models/project_task_model.dart';

class TaskDetailsRepositoryImpl
    implements
        TaskDetailsRepository,
        TaskResourceCreationRepository,
        TaskLabelCatalogRepository,
        TaskDatesRepository,
        TaskResourceOperationsRepository,
        TaskAdvancedRepository,
        TaskTitleRepository,
        TaskExtrasRepository,
        ProjectEpicCreationRepository,
        TaskAssigneesRepository,
        TaskTimingRepository,
        TaskTimerRepository {
  const TaskDetailsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> createEpic({
    required String projectId,
    required String name,
    required String color,
  }) async {
    final title = name.trim();
    if (title.isEmpty) {
      throw const TaskDetailsException('Введите название эпика.');
    }
    try {
      await _dio.post<dynamic>(
        'epics',
        data: {'projectId': projectId, 'name': title, 'color': color},
      );
    } on DioException catch (e) {
      throw TaskDetailsException(_messageFor(e, 'создать эпик'));
    }
  }

  @override
  Future<TaskDetailsPayload> updateDates(
    String taskId,
    DateTime? start,
    DateTime? end,
  ) => _patch(taskId, {
    'start': start?.toUtc().toIso8601String(),
    'end': end?.toUtc().toIso8601String(),
  });

  @override
  Future<void> patchResource(String id, Map<String, Object?> changes) async {
    try {
      await _dio.patch<Object?>(
        'resources/${Uri.encodeComponent(id)}',
        data: changes,
      );
    } on DioException {
      throw const TaskDetailsException(
        'Не удалось изменить ресурс. Повторите попытку.',
      );
    }
  }

  @override
  Future<Map<String, Object?>> resourceHistory(
    String id, {
    String? cursor,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'resources/${Uri.encodeComponent(id)}/history',
        queryParameters: {'take': 20, 'cursor': ?cursor},
      );
      return Map<String, Object?>.from(response.data ?? {});
    } on DioException {
      throw const TaskDetailsException('Не удалось загрузить историю ресурса.');
    }
  }

  @override
  Future<TaskDetailsPayload> updateStart(String taskId, DateTime? start) =>
      _patch(taskId, {'start': start?.toUtc().toIso8601String()});
  @override
  Future<TaskDetailsPayload> updateDependencies(
    String taskId,
    List<String> displayIds,
  ) => _patch(taskId, {'deps': displayIds.toSet().toList()});
  @override
  Future<TaskCommentModel> postComment(
    String taskId,
    String text,
    List<TaskFileModel> files,
  ) async {
    try {
      final response = await _dio.post<dynamic>(
        'project-tasks/${Uri.encodeComponent(taskId)}/comments',
        data: {
          'text': text.trim(),
          if (files.isNotEmpty)
            'files': files
                .map(
                  (f) => {
                    'name': f.name,
                    'dataUrl': f.dataUrl,
                    'size': f.size.toString(),
                    'type': f.type,
                  },
                )
                .toList(),
        },
      );
      return TaskCommentModel.fromJson(_object(response.data));
    } on DioException catch (e) {
      throw TaskDetailsException(_messageFor(e, 'отправить комментарий'));
    }
  }

  @override
  Future<TaskLabelCatalog> getLabelCatalog(String taskId) async {
    try {
      final response = await _dio.get<dynamic>(
        'project-tasks/${Uri.encodeComponent(taskId)}/label-catalog',
      );
      return TaskLabelCatalog.fromJson(_object(response.data));
    } on DioException catch (e) {
      throw TaskDetailsException(_messageFor(e, 'загрузить метки'));
    }
  }

  @override
  Future<List<TaskEpicModel>> getEpics(String projectId) async {
    try {
      final response = await _dio.get<dynamic>(
        'epics',
        queryParameters: {'projectId': projectId},
      );
      final data = response.data;
      final items = data is List
          ? data
          : data is Map
          ? data['data'] ?? data['items'] ?? []
          : [];
      return (items as List)
          .whereType<Map>()
          .map(
            (item) => TaskEpicModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } on DioException {
      throw const TaskDetailsException('Не удалось загрузить эпики.');
    }
  }

  @override
  Future<TaskDetailsPayload> updateEpics(String taskId, List<String> ids) =>
      _patch(taskId, {'epicIds': ids});
  @override
  Future<TaskResourceModel> createResource(
    String taskId,
    TaskResourceModel resource,
  ) async {
    try {
      final response = await _dio.post<dynamic>(
        'tasks/${Uri.encodeComponent(taskId)}/resources',
        data: {
          'name': resource.name,
          'planValue': resource.planValue.toStringAsFixed(4),
          'factValue': resource.factValue.toStringAsFixed(4),
        },
      );
      final body = _object(response.data);
      final model = TaskResourceModel.fromJson(
        body['data'] is Map
            ? Map<String, dynamic>.from(body['data'] as Map)
            : body,
      );
      if (model.id.isEmpty) {
        throw const TaskDetailsException('Сервер не вернул ID ресурса.');
      }
      return model;
    } on DioException {
      throw const TaskDetailsException('Не удалось создать ресурс.');
    }
  }

  @override
  Future<void> saveResource(
    String taskId,
    TaskResourceModel resource, {
    required bool create,
  }) async {
    final data = <String, dynamic>{
      'name': resource.name,
      'planValue': resource.planValue.toStringAsFixed(4),
      'factValue': resource.factValue.toStringAsFixed(4),
    };
    try {
      if (create) {
        await _dio.post<dynamic>(
          'tasks/${Uri.encodeComponent(taskId)}/resources',
          data: data,
        );
      } else {
        await _dio.patch<dynamic>(
          'resources/${Uri.encodeComponent(resource.id)}',
          data: data,
        );
      }
    } on DioException catch (e) {
      throw TaskDetailsException(
        e.response?.statusCode == 403
            ? 'Недостаточно прав для изменения ресурсов.'
            : 'Не удалось сохранить ресурс.',
      );
    }
  }

  @override
  Future<void> deleteResource(String resourceId) async {
    try {
      await _dio.delete<dynamic>(
        'resources/${Uri.encodeComponent(resourceId)}',
      );
    } on DioException {
      throw const TaskDetailsException('Не удалось удалить ресурс.');
    }
  }

  @override
  Future<TaskDetailsPayload> updateTitle(String taskId, String title) =>
      _patch(taskId, {'title': title.trim()});

  @override
  Future<TaskDetailsPayload> updateEstimate(
    String taskId,
    int minutes, {
    TaskDetailModel? detail,
  }) => _patch(taskId, {
    'est': (minutes / 60).ceil(),
    'detail': (detail ?? const TaskDetailModel())
        .copyWith(estimateMinutes: minutes)
        .toJson(),
  });

  @override
  Future<TaskDetailsPayload> timerAction(String taskId, String action) {
    if (!['start', 'pause', 'reset'].contains(action)) {
      throw const TaskDetailsException('Неизвестное действие таймера.');
    }
    return _patch(taskId, {'timerAction': action});
  }

  @override
  Future<List<TaskAssigneeModel>> getAssigneeCandidates(
    String projectId,
  ) async {
    try {
      final project = _object(
        (await _dio.get<dynamic>(
          'projects/${Uri.encodeComponent(projectId)}',
        )).data,
      );
      final workspaceId =
          project['workspaceId']?.toString() ??
          project['workspace_id']?.toString() ??
          '';
      if (workspaceId.isEmpty) {
        throw const TaskDetailsException(
          'Не удалось определить рабочее пространство проекта.',
        );
      }
      final response = await _dio.get<dynamic>(
        'users',
        queryParameters: {'workspaceId': workspaceId},
      );
      return _list(response.data)
          .whereType<Map>()
          .map(
            (user) => TaskAssigneeModel.fromJson({
              'user': Map<String, dynamic>.from(user),
            }),
          )
          .where((user) => user.userId.isNotEmpty)
          .toList();
    } on DioException catch (error) {
      throw TaskDetailsException(_messageFor(error, 'загрузить исполнителей'));
    } on TaskDetailsException {
      rethrow;
    } catch (_) {
      throw const TaskDetailsException('Не удалось загрузить исполнителей.');
    }
  }

  @override
  Future<TaskDetailsPayload> updateAssignees(
    String taskId,
    List<String> userIds,
  ) => _patch(taskId, {'assigneeIds': userIds.toSet().toList()});

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
  Future<TaskDetailsPayload> updateProgress(
    String taskId,
    int progress, {
    String? status,
  }) {
    return _patch(taskId, <String, dynamic>{
      'progress': progress,
      'status': ?status,
    });
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
      for (final key in const <String>[
        'data',
        'history',
        'items',
        'columns',
        'users',
      ]) {
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
        if (code == 401) return 'Сессия истекла. Войдите снова.';
        if (code == 403) return 'Недостаточно прав для этого действия.';
        if (code == 400 || code == 409) {
          final body = error.response?.data;
          final message = body is Map ? body['message'] : null;
          if (message is String && message.trim().isNotEmpty) return message;
          if (message is List && message.every((e) => e is String)) {
            return message.join('\n');
          }
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
