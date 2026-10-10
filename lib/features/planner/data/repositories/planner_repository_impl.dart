import 'package:dio/dio.dart';
import '../../domain/repositories/planner_repository.dart';
import '../models/planner_item_model.dart';

class PlannerRepositoryImpl implements PlannerRepository {
  const PlannerRepositoryImpl(this._dio);
  final Dio _dio;

  Future<T> _request<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw PlannerException(
        e.response?.statusCode == 403
            ? 'Недостаточно прав для изменения ежедневника.'
            : e.type == DioExceptionType.connectionError
            ? 'Нет подключения к интернету.'
            : 'Не удалось обновить ежедневник. Попробуйте ещё раз.',
      );
    }
  }

  @override
  Future<List<PlannerItemModel>> load(String workspaceId) => _request(() async {
    final response = await _dio.get<dynamic>(
      'project-planner/workspace/$workspaceId',
    );
    final data = response.data;
    final items = data is List
        ? data
        : data is Map
        ? data['items'] ?? data['data']
        : null;
    if (items is! List) {
      throw const PlannerException(
        'Сервер вернул некорректные данные ежедневника.',
      );
    }
    return items
        .whereType<Map>()
        .map((e) => PlannerItemModel.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id.isNotEmpty && !e.archived)
        .toList();
  });

  @override
  Future<PlannerItemModel> create(
    String workspaceId, {
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) => _request(() async {
    final response = await _dio.post<dynamic>(
      'project-planner/workspace/$workspaceId/tasks',
      data: {
        'title': title.trim(),
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'durationMinutes': durationMinutes,
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw const PlannerException('Сервер вернул некорректную задачу.');
    }
    final object = data['data'] is Map ? data['data'] as Map : data;
    return PlannerItemModel.fromJson(Map<String, dynamic>.from(object));
  });

  @override
  Future<void> update(
    PlannerItemModel item, {
    String? title,
    DateTime? scheduledAt,
    int? durationMinutes,
    bool? completed,
  }) => _request(() async {
    if (completed != null && item.taskId != null) {
      await _dio.patch<dynamic>(
        'project-tasks/${item.taskId}',
        data: {
          'progress': completed ? 100 : 0,
          if (!completed && item.task?.status.toUpperCase() == 'DONE')
            'status': 'TODO',
        },
      );
      return;
    }
    await _dio.patch<dynamic>(
      'project-planner/items/${item.id}',
      data: {
        'title': ?title,
        'scheduledAt': ?scheduledAt?.toUtc().toIso8601String(),
        'durationMinutes': ?durationMinutes,
        'completed': ?completed,
      },
    );
  });

  @override
  Future<void> remove(String itemId) => _request(() async {
    await _dio.delete<dynamic>('project-planner/items/$itemId');
  });

  @override
  Future<void> addTask(
    String workspaceId, {
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) => _request(() async {
    await _dio.post<dynamic>(
      inboxTaskId != null
          ? 'project-planner/workspace/$workspaceId/inbox-tasks'
          : 'project-planner/$projectId/tasks',
      data: {
        'taskId': ?taskId,
        'inboxTaskId': ?inboxTaskId,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'durationMinutes': durationMinutes,
      },
    );
  });
}
