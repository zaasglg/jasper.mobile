import '../../../tasks/data/models/kanban_column_dto.dart';
import '../../../workspaces/data/models/workspace_dto.dart';
import 'package:dio/dio.dart';
import '../../../projects/data/models/project_model.dart';
import '../../../tasks/domain/entities/kanban_column_model.dart';
import '../../../workspaces/domain/entities/workspace_model.dart';
import '../../domain/entities/task_move_target.dart';
import '../../domain/repositories/kanban_repository.dart';
import '../../domain/repositories/task_move_repository.dart';

class TaskMoveRepositoryImpl implements TaskMoveRepository {
  const TaskMoveRepositoryImpl(this._dio);
  final Dio _dio;
  Options _scope(String workspaceId) =>
      Options(headers: {'X-Workspace-Id': workspaceId});

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is Map) {
      for (final key in [
        'data',
        'items',
        'workspaces',
        'projects',
        'columns',
      ]) {
        if (value[key] is List || value[key] is Map) return _rows(value[key]);
      }
    }
    if (value is! List) {
      throw const KanbanException(
        'Сервер вернул некорректный список мест назначения.',
      );
    }
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<T> _request<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      final code = error.response?.statusCode;
      throw KanbanException(switch (code) {
        401 => 'Сессия истекла. Войдите снова.',
        403 => 'Недостаточно прав для выбранного проекта или колонки.',
        404 =>
          'Задача или место назначения больше недоступны. Обновите список.',
        _ =>
          error.type == DioExceptionType.connectionError
              ? 'Нет подключения к интернету.'
              : 'Не удалось выполнить действие. Попробуйте ещё раз.',
      }, statusCode: code);
    }
  }

  @override
  Future<List<WorkspaceModel>> workspaces({CancelToken? cancelToken}) =>
      _request(
        () async =>
            _rows(
                  (await _dio.get<dynamic>(
                    'workspaces',
                    cancelToken: cancelToken,
                  )).data,
                )
                .where(
                  (row) => row['archived'] != true && row['archivedAt'] == null,
                )
                .map((json) => WorkspaceDto.fromJson(json).toEntity())
                .where((item) => item.id.isNotEmpty)
                .toList(),
      );

  @override
  Future<List<ProjectModel>> projects(
    String workspaceId, {
    CancelToken? cancelToken,
  }) => _request(() async {
    final rows = _rows(
      (await _dio.get<dynamic>(
        'projects',
        options: _scope(workspaceId),
        cancelToken: cancelToken,
      )).data,
    );
    final result = <String, ProjectModel>{};
    void collect(Map<String, dynamic> row, String inheritedWorkspace) {
      if (row['archived'] == true || row['archivedAt'] != null) return;
      final workspace = row['workspaceId']?.toString() ?? inheritedWorkspace;
      if (workspace != workspaceId) return;
      final project = ProjectModel.fromJson({...row, 'workspaceId': workspace});
      if (project.id.isNotEmpty) result[project.id] = project;
      final children = row['children'];
      if (children is List) {
        for (final child in children.whereType<Map>()) {
          collect(Map<String, dynamic>.from(child), workspace);
        }
      }
    }

    for (final row in rows) {
      collect(row, workspaceId);
    }
    return result.values.toList();
  });

  @override
  Future<List<KanbanColumnModel>> columns(
    String workspaceId,
    String projectId, {
    CancelToken? cancelToken,
  }) => _request(() async {
    final columns =
        _rows(
              (await _dio.get<dynamic>(
                'kanban-columns',
                queryParameters: {'projectId': projectId},
                options: _scope(workspaceId),
                cancelToken: cancelToken,
              )).data,
            )
            .where((row) => row['archivedAt'] == null)
            .map((json) => KanbanColumnDto.fromJson(json).toEntity())
            .where(
              (column) =>
                  column.id.isNotEmpty &&
                  !column.archived &&
                  column.statusMap.isNotEmpty &&
                  (column.projectId.isEmpty || column.projectId == projectId),
            )
            .toList();
    columns.sort((a, b) => a.order.compareTo(b.order));
    return columns;
  });

  @override
  Future<void> move(String taskId, TaskMoveTarget target) => _request(() async {
    await _dio.post<dynamic>(
      'project-tasks/${Uri.encodeComponent(taskId)}/move',
      options: _scope(target.workspaceId),
      data: {
        'projectId': target.projectId,
        'status': target.status,
        'position': ?target.position,
      },
    );
  });
}
