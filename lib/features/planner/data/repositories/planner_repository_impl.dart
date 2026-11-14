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
            ? 'Нет доступа к этой записи ежедневника.'
            : e.type == DioExceptionType.connectionError
            ? 'Нет подключения к интернету.'
            : 'Не удалось обновить ежедневник. Попробуйте ещё раз.',
      );
    }
  }

  @override
  Future<List<PlannerItemModel>> load() => _request(() async {
    const pageSize = 250;
    final result = <String, PlannerItemModel>{};
    for (var skip = 0; ; skip += pageSize) {
      final response = await _dio.get<dynamic>(
        'project-planner/account',
        queryParameters: {'skip': skip, 'take': pageSize},
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
      for (final json in items.whereType<Map>()) {
        final item = PlannerItemModel.fromJson(Map<String, dynamic>.from(json));
        if (item.id.isNotEmpty && !item.archived) result[item.id] = item;
      }
      if (items.length < pageSize) return result.values.toList();
    }
  });

  @override
  Future<PlannerItemModel> create({
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) => _request(() async {
    final response = await _dio.post<dynamic>(
      'project-planner/account/tasks',
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
  Future<void> addTask({
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) => _request(() async {
    await _dio.post<dynamic>(
      inboxTaskId != null
          ? 'project-planner/account/inbox-tasks'
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
