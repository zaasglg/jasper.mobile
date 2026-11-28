import '../../../tasks/data/models/task_detail_model.dart';
import 'package:dio/dio.dart';
import '../../domain/repositories/planner_repository.dart';
import '../../domain/utils/planner_dates.dart';
import '../models/planner_item_model.dart';

class PlannerRepositoryImpl implements PlannerRepository {
  const PlannerRepositoryImpl(this._dio);
  final Dio _dio;

  Future<T> _request<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 &&
          e.requestOptions.path.contains('/day-')) {
        throw const PlannerException(
          'Для добавления плана без времени требуется обновление сервера ежедневника.',
        );
      }
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
    final seenIds = <String>{};
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
      var hasNewIds = false;
      for (final json in items.whereType<Map>()) {
        final item = PlannerItemModel.fromJson(Map<String, dynamic>.from(json));
        if (item.id.isNotEmpty && seenIds.add(item.id)) hasNewIds = true;
        if (item.id.isNotEmpty && !item.archived) result[item.id] = item;
      }
      if (items.isNotEmpty && !hasNewIds) {
        throw const PlannerException(
          'Сервер вернул страницу ежедневника без новых записей. Повторите загрузку.',
        );
      }
      if (items.length < pageSize) return result.values.toList();
    }
  });

  @override
  Future<PlannerItemModel> create({
    required String title,
    required DateTime? scheduledAt,
    DateTime? plannedDate,
    required int durationMinutes,
  }) => _request(() async {
    _validateDay(scheduledAt, plannedDate);
    final response = await _dio.post<dynamic>(
      'project-planner/account/tasks',
      data: {
        'title': title.trim(),
        'scheduledAt': (scheduledAt ?? plannerDate(plannedDate!))
            .toUtc()
            .toIso8601String(),
        'hasTime': scheduledAt != null,
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
    DateTime? plannedDate,
    int? durationMinutes,
    bool? completed,
    int? reminderMinutes,
  }) => _request(() async {
    final linkedProjectCompletion = completed != null && item.taskId != null;
    final data = <String, dynamic>{
      'title': ?title,
      if (scheduledAt != null || plannedDate != null) ...{
        'scheduledAt': (scheduledAt ?? plannerDate(plannedDate!))
            .toUtc()
            .toIso8601String(),
        'hasTime': scheduledAt != null,
      },
      'durationMinutes': ?durationMinutes,
      if (!linkedProjectCompletion) 'completed': ?completed,
      'reminderMinutes': ?reminderMinutes,
    };
    // Match web: project completion updates source progress; personal and
    // Inbox completion uses the ordinary planner item endpoint.
    if (!linkedProjectCompletion || data.isNotEmpty) {
      await _dio.patch<dynamic>(
        'project-planner/items/${Uri.encodeComponent(item.id)}',
        data: data,
      );
    }
    if (linkedProjectCompletion) {
      await _dio.patch<dynamic>(
        'project-tasks/${Uri.encodeComponent(item.taskId!)}',
        data: {'progress': completed ? 100 : 0},
      );
    }
  });

  @override
  Future<void> updateExtras(
    String itemId, {
    bool updateIcon = false,
    String? icon,
    List<TaskChecklistModel>? checklists,
  }) => _request(() async {
    await _dio.patch<dynamic>(
      'project-planner/items/${Uri.encodeComponent(itemId)}',
      data: {
        if (updateIcon) 'icon': icon,
        if (checklists != null)
          'checklists': checklists.map(_checklistPayload).toList(),
      },
    );
  });

  // Planner DTOs validate an optional dueDate as a string when present.
  // Task models serialize absent dates as null, which this endpoint rejects.
  static Map<String, dynamic> _checklistItemPayload(
    TaskChecklistItemModel item,
  ) => {
    'id': item.id,
    'text': item.text,
    'done': item.done,
    if (item.dueDate != null) 'dueDate': item.dueDate!.toIso8601String(),
    'assigneeIds': item.assigneeIds,
  };

  static Map<String, dynamic> _checklistPayload(TaskChecklistModel list) => {
    'id': list.id,
    'name': list.name,
    'items': list.items.map(_checklistItemPayload).toList(),
    'sections': [
      for (final section in list.sections)
        {
          'id': section.id,
          'name': section.name,
          'items': section.items.map(_checklistItemPayload).toList(),
        },
    ],
  };

  @override
  Future<void> remove(String itemId) async {
    try {
      await _dio.delete<dynamic>(
        'project-planner/items/${Uri.encodeComponent(itemId)}',
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      final raw = data is Map ? data['message'] : null;
      final message = raw is String
          ? raw.trim()
          : raw is List
          ? raw.whereType<String>().join(' ').trim()
          : '';
      final reason = switch (status) {
        401 => 'Сессия истекла. Войдите снова.',
        403 => 'Нет прав убрать эту запись из ежедневника.',
        404 => 'Сервер не нашёл запись ежедневника. Обновите список.',
        400 ||
        409 ||
        422 => message.isEmpty ? 'Сервер отклонил удаление записи.' : message,
        _ =>
          error.type == DioExceptionType.connectionError
              ? 'Нет подключения к интернету. Запись не удалена.'
              : 'Не удалось убрать запись из ежедневника. Повторите попытку.',
      };
      throw PlannerException(
        status == null ? reason : '$reason (HTTP $status)',
      );
    }
  }

  @override
  Future<void> addTask({
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime? scheduledAt,
    DateTime? plannedDate,
    required int durationMinutes,
  }) => _request(() async {
    _validateDay(scheduledAt, plannedDate);
    await _dio.post<dynamic>(
      inboxTaskId != null
          ? 'project-planner/account/${scheduledAt == null ? 'day-inbox-tasks' : 'inbox-tasks'}'
          : 'project-planner/$projectId/${scheduledAt == null ? 'day-tasks' : 'tasks'}',
      data: {
        'taskId': ?taskId,
        'inboxTaskId': ?inboxTaskId,
        'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
        if (plannedDate != null) 'plannedDate': plannerDayString(plannedDate),
        'durationMinutes': durationMinutes,
      },
    );
  });
  void _validateDay(DateTime? time, DateTime? day) {
    if (time == null && day == null) {
      throw const PlannerException('Выберите день для записи без времени.');
    }
  }
}
