import 'package:dio/dio.dart';

import '../../../projects/data/models/project_task_model.dart';
import '../../../tasks/data/models/kanban_column_model.dart';
import '../../domain/entities/kanban_board_data.dart';
import '../../domain/repositories/kanban_repository.dart';

class KanbanRepositoryImpl implements KanbanRepository {
  KanbanRepositoryImpl(this._dio);

  final Dio _dio;
  CancelToken? _loadCancelToken;

  @override
  Future<KanbanBoardData> loadBoard(
    String projectId, {
    String? search,
    int take = 100,
    int skip = 0,
  }) async {
    _loadCancelToken?.cancel('Board switched');
    final token = CancelToken();
    _loadCancelToken = token;
    try {
      final responses = await Future.wait<Response<dynamic>>(
        <Future<Response<dynamic>>>[
          _dio.get<dynamic>(
            'kanban-columns',
            queryParameters: <String, dynamic>{'projectId': projectId},
            cancelToken: token,
          ),
          _dio.get<dynamic>(
            'project-tasks',
            queryParameters: <String, dynamic>{
              'projectId': projectId,
              'archived': false,
              'take': take,
              'skip': skip,
              if (search != null && search.trim().isNotEmpty)
                'search': search.trim(),
            },
            cancelToken: token,
          ),
        ],
      );
      return KanbanBoardData(
        columns: _list(responses[0].data)
            .whereType<Map>()
            .map(
              (item) =>
                  KanbanColumnModel.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((column) => column.id.isNotEmpty && !column.archived)
            .toList(growable: false),
        tasks: _list(responses[1].data)
            .whereType<Map>()
            .map(
              (item) =>
                  ProjectTaskModel.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((task) => task.id.isNotEmpty && !task.archived)
            .toList(growable: false),
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const KanbanException('Запрос отменён.');
      }
      throw _exception(error, 'загрузить доску');
    } on KanbanException {
      rethrow;
    } catch (_) {
      throw const KanbanException('Не удалось загрузить Kanban-доску.');
    } finally {
      if (identical(_loadCancelToken, token)) _loadCancelToken = null;
    }
  }

  @override
  void cancelPendingLoads() => _loadCancelToken?.cancel('Board disposed');

  @override
  Future<ProjectTaskModel> createTask({
    required String projectId,
    required String title,
    required String status,
    required String priority,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        'project-tasks',
        data: <String, dynamic>{
          'projectId': projectId,
          'title': title.trim(),
          'status': status,
          'priority': priority,
          'progress': 0,
          'assigneeIds': const <String>[],
          'epicIds': const <String>[],
          'deps': const <String>[],
          'est': 0,
        },
      );
      return ProjectTaskModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw _exception(error, 'создать задачу');
    } on KanbanException {
      rethrow;
    }
  }

  @override
  Future<void> moveTask({
    required String taskId,
    required String projectId,
    required String status,
    required int position,
  }) async {
    try {
      await _dio.post<dynamic>(
        'project-tasks/$taskId/move',
        data: <String, dynamic>{
          'projectId': projectId,
          'status': status,
          'position': position,
        },
      );
    } on DioException catch (error) {
      throw _exception(error, 'переместить задачу');
    }
  }

  @override
  Future<KanbanColumnModel> createColumn({
    required String projectId,
    required String name,
    required int order,
    int? wip,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        'kanban-columns',
        data: <String, dynamic>{
          'projectId': projectId,
          'name': name.trim(),
          'color': '#6366F1',
          'wip': wip,
          'order': order,
        },
      );
      return KanbanColumnModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw _exception(error, 'создать колонку');
    } on KanbanException {
      rethrow;
    }
  }

  @override
  Future<KanbanColumnModel> updateColumn({
    required String columnId,
    required String name,
    int? wip,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        'kanban-columns/$columnId',
        data: <String, dynamic>{'name': name.trim(), 'wip': wip},
      );
      return KanbanColumnModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw _exception(error, 'обновить колонку');
    } on KanbanException {
      rethrow;
    }
  }

  @override
  Future<void> reorderColumns(String projectId, List<String> ids) async {
    try {
      await _dio.post<dynamic>(
        'kanban-columns/reorder',
        data: <String, dynamic>{'projectId': projectId, 'ids': ids},
      );
    } on DioException catch (error) {
      throw _exception(error, 'изменить порядок колонок');
    }
  }

  @override
  Future<void> archiveColumn(String columnId) async {
    try {
      await _dio.patch<dynamic>('kanban-columns/$columnId/archive');
    } on DioException catch (error) {
      throw _exception(error, 'архивировать колонку');
    }
  }

  @override
  Future<void> deleteColumn(String columnId) async {
    try {
      await _dio.delete<dynamic>('kanban-columns/$columnId');
    } on DioException catch (error) {
      throw _exception(error, 'удалить колонку');
    }
  }

  List<dynamic> _list(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final value = Map<String, dynamic>.from(data);
      for (final key in const <String>['data', 'items', 'tasks', 'columns']) {
        final nested = value[key];
        if (nested is List) return nested;
        if (nested is Map) {
          final nestedMap = Map<String, dynamic>.from(nested);
          for (final innerKey in const <String>['items', 'tasks', 'columns']) {
            if (nestedMap[innerKey] is List) return nestedMap[innerKey] as List;
          }
        }
      }
    }
    throw const KanbanException('Сервер вернул некорректные данные доски.');
  }

  Map<String, dynamic> _object(dynamic data) {
    if (data is! Map) {
      throw const KanbanException('Сервер вернул некорректные данные.');
    }
    final value = Map<String, dynamic>.from(data);
    final nested = value['data'];
    return nested is Map ? Map<String, dynamic>.from(nested) : value;
  }

  KanbanException _exception(DioException error, String action) {
    final code = error.response?.statusCode;
    if (code == 403) {
      return KanbanException(
        'Недостаточно прав, чтобы $action.',
        statusCode: code,
      );
    }
    if (code == 404) {
      return KanbanException(
        'Объект не найден или уже удалён.',
        statusCode: code,
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.transformTimeout) {
      return KanbanException(
        'Сервер не отвечает. Попробуйте ещё раз.',
        statusCode: code,
      );
    }
    if (error.type == DioExceptionType.connectionError) {
      return KanbanException('Нет подключения к интернету.', statusCode: code);
    }
    return KanbanException('Не удалось $action.', statusCode: code);
  }
}
