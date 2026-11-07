import 'package:dio/dio.dart';
import '../../../../core/storage/workspace_selection_storage.dart';
import '../../domain/repositories/assistant_repository.dart';

/// Uses the same extraction and confirmation endpoints as the web agent.
class AssistantActions {
  const AssistantActions(this.dio, this.selection);
  final Dio dio;
  final WorkspaceSelectionStorage selection;
  Map<String, dynamic> body(dynamic value) {
    if (value is Map && value['data'] is Map) value = value['data'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  Future<void> checkWorkspace(String workspaceId) async {
    final selected = await selection.read();
    if (selected != null && selected != workspaceId) {
      throw const AssistantException(
        'Рабочее пространство изменилось. Откройте помощника заново.',
      );
    }
  }

  Options options(String id) => Options(headers: {'X-Workspace-Id': id});
  Future<Map<String, dynamic>?> extract(
    String workspaceId,
    String text,
    List<String> images,
    String? projectId,
  ) async {
    await checkWorkspace(workspaceId);
    final result = body(
      (await dio.post<dynamic>(
        'ai/extract-task',
        options: options(workspaceId),
        data: {
          'workspaceId': workspaceId,
          'messageText': text,
          'projectId': ?projectId,
          if (images.isNotEmpty) 'images': images,
        },
      )).data,
    );
    if (result['isTaskDetected'] != true || result['suggestedTask'] is! Map) {
      return null;
    }
    final draft = Map<String, dynamic>.from(result['suggestedTask'] as Map);
    if (draft['title'] is! String ||
        (draft['title'] as String).trim().isEmpty) {
      return null;
    }
    return {...draft, 'resolvedAssigneeId': result['resolvedAssigneeId']};
  }

  Future<List<Map<String, dynamic>>> projects(String workspaceId) async {
    final raw = (await dio.get<dynamic>(
      'projects',
      options: options(workspaceId),
    )).data;
    final data = raw is Map ? raw['data'] ?? raw['items'] : raw;
    return (data is List ? data : const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['workspaceId'] == workspaceId && e['archived'] != true)
        .toList();
  }

  Future<void> create(
    String workspaceId,
    String projectId,
    Map<String, dynamic> draft,
  ) async {
    await checkWorkspace(workspaceId);
    final available = await projects(workspaceId);
    if (!available.any((e) => e['id'] == projectId)) {
      throw const AssistantException('Проект недоступен в этом пространстве.');
    }
    await checkWorkspace(workspaceId);
    await dio.post<dynamic>(
      'ai/extract-task/confirm',
      options: options(workspaceId),
      data: {
        'projectId': projectId,
        'title': draft['title'],
        if (draft['description'] != null) 'description': draft['description'],
        if (draft['resolvedAssigneeId'] != null)
          'assigneeId': draft['resolvedAssigneeId'],
        'dueDate': draft['dueDate'],
      },
    );
  }

  static bool validField(String key, dynamic value) {
    if (key == 'title') {
      return value is String && value.trim().isNotEmpty && value.length <= 500;
    }
    if (key == 'priority') {
      return ['LOW', 'MED', 'HIGH', 'CRIT'].contains(value);
    }
    if (!['start', 'end'].contains(key)) return false;
    if (value == null) return true;
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return false;
    }
    return DateTime.tryParse(value)?.toIso8601String().substring(0, 10) ==
        value;
  }

  static bool validEdit(Map draft, String workspaceId) {
    final patch = draft['patch'], previous = draft['previous'];
    return draft['type'] == 'task_edit_draft' &&
        draft['workspaceId'] == workspaceId &&
        ['taskId', 'projectId', 'title'].every(
          (key) =>
              draft[key] is String && (draft[key] as String).trim().isNotEmpty,
        ) &&
        patch is Map &&
        previous is Map &&
        patch.isNotEmpty &&
        patch.keys.every(
          (key) =>
              key is String &&
              validField(key, patch[key]) &&
              validField(key, previous[key]),
        );
  }

  Future<void> apply(String workspaceId, Map<String, dynamic> draft) async {
    if (!validEdit(draft, workspaceId)) {
      throw const AssistantException('Некорректный черновик изменений.');
    }
    await checkWorkspace(workspaceId);
    final id = Uri.encodeComponent(draft['taskId'] as String);
    final current = body(
      (await dio.get<dynamic>(
        'project-tasks/$id',
        options: options(workspaceId),
      )).data,
    );
    if (current['id'] != draft['taskId'] ||
        current['projectId'] != draft['projectId'] ||
        current['workspaceId'] != workspaceId) {
      throw const AssistantException(
        'Задача больше не доступна в этом пространстве.',
      );
    }
    for (final key in (draft['patch'] as Map).keys) {
      final value = current[key];
      final normalized = ['start', 'end'].contains(key)
          ? value is String
                ? value.split('T').first
                : null
          : value;
      if (normalized != (draft['previous'] as Map)[key]) {
        throw const AssistantException(
          'Задача уже изменена. Попросите AI подготовить изменения заново.',
        );
      }
    }
    await checkWorkspace(workspaceId);
    await dio.patch<dynamic>(
      'project-tasks/$id',
      options: options(workspaceId),
      data: draft['patch'],
    );
  }
}
