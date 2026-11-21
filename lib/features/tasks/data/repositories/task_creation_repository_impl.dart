import '../../../projects/domain/entities/project_model.dart';
import '../../../projects/data/models/project_dto.dart';
import '../../../projects/domain/entities/project_task_model.dart';
import '../../../projects/data/models/project_task_dto.dart';
import '../../../projects/domain/entities/task_assignee_model.dart';
import '../../../projects/data/models/task_assignee_dto.dart';
import 'package:dio/dio.dart';
import '../../domain/repositories/task_creation_repository.dart';
import '../models/task_creation_models.dart';

class TaskCreationRepositoryImpl implements TaskCreationRepository {
  const TaskCreationRepositoryImpl(this.dio);
  final Dio dio;
  Options _options(String workspaceId) =>
      Options(headers: {'X-Workspace-Id': workspaceId});
  Map<String, dynamic> _object(dynamic data) {
    if (data is Map) {
      if (data['data'] is Map) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      return Map<String, dynamic>.from(data);
    }
    throw const TaskCreationException('Некорректный ответ сервера');
  }

  List<Map<String, dynamic>> _items(dynamic data) {
    if (data is Map) {
      data =
          data['data'] ??
          data['items'] ??
          data['members'] ??
          data['projects'] ??
          data['workspaces'];
    }
    if (data is! List) {
      throw const TaskCreationException('Не удалось прочитать список');
    }
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<TaskCreationCatalog> catalog() async {
    final values = await Future.wait([
      dio.get<dynamic>('workspaces'),
      dio.get<dynamic>('users/me'),
    ]);
    return TaskCreationCatalog.fromJson({
      'workspaces': _items(values[0].data),
      'user': _object(values[1].data),
    });
  }

  @override
  Future<List<ProjectModel>> projects(String workspaceId) async {
    final rows = _items(
      (await dio.get<dynamic>('projects', options: _options(workspaceId))).data,
    );
    final roots = rows
        .map((json) => ProjectDto.fromJson(json).toEntity())
        .where((e) => e.workspaceId == workspaceId)
        .toList();
    List<ProjectModel> flatten(List<ProjectModel> values) => [
      for (final value in values) ...[value, ...flatten(value.children)],
    ];
    return {
      for (final value in flatten(roots)) value.id: value,
    }.values.toList();
  }

  @override
  Future<List<TaskAssigneeModel>> members(String workspaceId) async {
    final rows = _items(
      (await dio.get<dynamic>(
        'workspaces/${Uri.encodeComponent(workspaceId)}/members',
        options: _options(workspaceId),
      )).data,
    );
    final result = <String, TaskAssigneeModel>{};
    for (final row in rows) {
      final member = _member(row);
      if (member.userId.isNotEmpty) result[member.userId] = member;
    }
    return result.values.toList();
  }

  TaskAssigneeModel _member(Map<String, dynamic> row) {
    final user = row['user'] is Map
        ? Map<String, dynamic>.from(row['user'] as Map)
        : row;
    return TaskAssigneeDto.fromJson({
      'userId': user['id'] ?? row['userId'],
      'name': user['name'] ?? row['name'],
      'avatarUrl': user['avatarUrl'] ?? row['avatarUrl'],
    }).toEntity();
  }

  @override
  Future<TaskCreationOptions> options(
    String workspaceId,
    String projectId,
  ) async {
    final result = await Future.wait([
      dio.get<dynamic>(
        'kanban-columns',
        queryParameters: {'projectId': projectId},
        options: _options(workspaceId),
      ),
      dio.get<dynamic>(
        'epics',
        queryParameters: {'projectId': projectId},
        options: _options(workspaceId),
      ),
      members(workspaceId),
    ]);
    final tasks = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (var skip = 0; ; skip += 100) {
      final page = _items(
        (await dio.get<dynamic>(
          'project-tasks',
          queryParameters: {
            'projectId': projectId,
            'archived': 'false',
            'take': 100,
            'skip': skip,
          },
          options: _options(workspaceId),
        )).data,
      );
      final newRows = page.where((e) => seen.add(e['id'].toString())).toList();
      tasks.addAll(newRows);
      if (page.length < 100) break;
      if (newRows.isEmpty) {
        throw const TaskCreationException('Сервер повторил страницу задач');
      }
    }
    final options = TaskCreationOptions.fromJson({
      'columns': _items((result[0] as Response<dynamic>).data),
      'epics': _items((result[1] as Response<dynamic>).data),
      'members': (result[2] as List<TaskAssigneeModel>)
          .map((e) => TaskAssigneeDto.fromEntity(e).toJson())
          .toList(),
      'tasks': tasks,
    });
    final memberMap = {
      for (final member in options.members.where((e) => e.userId.isNotEmpty))
        member.userId: member,
    };
    return options.copyWith(
      members: memberMap.values.toList(),
      columns:
          options.columns
              .where(
                (e) =>
                    !e.archived &&
                    e.statusMap.isNotEmpty &&
                    (e.projectId.isEmpty || e.projectId == projectId),
              )
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order)),
      tasks: options.tasks
          .where((e) => !e.archived && e.projectId == projectId)
          .toList(),
    );
  }

  @override
  Future<TaskCreationResult> create(
    TaskCreationRequest request,
    List<ProjectTaskModel> siblings,
  ) async {
    final body = request.toJson()..remove('workspaceId');
    final position = request.position.clamp(1, siblings.length + 1);
    body.remove('order');
    if (position > 1 && position <= siblings.length) {
      body['insertAfterTaskId'] = siblings[position - 2].id;
    } else if (position == 1 && siblings.isNotEmpty) {
      body['order'] = 1;
    }
    final response = await dio.post<dynamic>(
      'project-tasks',
      options: _options(request.workspaceId),
      data: body,
    );
    final task = ProjectTaskDto.fromJson(_object(response.data)).toEntity();
    if (task.id.isEmpty) {
      throw const TaskCreationException(
        'Сервер не вернул созданную задачу. Обновите список перед повторной попыткой.',
      );
    }
    var warning = false;
    if (position == 1 && siblings.isNotEmpty) {
      final ids = [task.id, ...siblings.map((e) => e.id)];
      try {
        await dio.patch<dynamic>(
          'project-tasks/batch-order',
          options: _options(request.workspaceId),
          data: {
            'updates': [
              for (var i = 0; i < ids.length; i++)
                {'id': ids[i], 'order': i + 1},
            ],
          },
        );
      } on DioException {
        warning = true;
      }
    }
    return TaskCreationResult(
      task: task,
      workspaceId: request.workspaceId,
      orderWarning: warning,
    );
  }
}
