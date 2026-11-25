import '../../domain/entities/assistant_request.dart';
import 'assistant_cancel_token.dart';
import '../../domain/entities/assistant_attachment.dart';
import '../../domain/entities/assistant_message_model.dart';
import 'assistant_api_errors.dart';
import '../../domain/entities/assistant_draft.dart';
import '../models/assistant_draft_dto.dart';
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

  Future<AssistantDraft?> extractDraft(
    String workspaceId,
    String text,
    List<String> images,
    String? projectId, {
    AssistantRequest? request,
  }) async {
    final value = await extract(
      workspaceId,
      text,
      images,
      projectId,
      request: request,
    );
    return value == null ? null : AssistantDraftDto.fromJson(value).toEntity();
  }

  Future<AssistantMessageModel?> extractAttachmentMessage(
    String workspaceId,
    String text,
    List<AssistantAttachment> attachments,
    List<String> images,
    String? projectId, {
    AssistantRequest? request,
  }) async {
    await checkWorkspace(workspaceId);
    try {
      final result = body(
        (await dio.post<dynamic>(
          'ai/extract-task',
          cancelToken: assistantCancelToken(request),
          options: Options(
            headers: {'X-Workspace-Id': workspaceId},
            receiveTimeout: const Duration(minutes: 4),
            sendTimeout: const Duration(minutes: 2),
          ),
          data: {
            'workspaceId': workspaceId,
            'messageText': text,
            'projectId': ?projectId,
            if (attachments.isNotEmpty)
              'attachments': attachments.map((e) => e.toUploadJson()).toList(),
            if (images.isNotEmpty) 'images': images,
          },
        )).data,
      );
      final reports = AssistantAttachment.parseList(result['attachments']);
      if (reports.length != attachments.length + images.length) {
        throw const AssistantException(
          'Не удалось подтвердить чтение файлов. Повторите запрос позже.',
        );
      }
      final warning = result['attachmentMessage'] is String
          ? result['attachmentMessage'] as String
          : '';
      final task = result['suggestedTask'];
      if (result['isTaskDetected'] == true &&
          task is Map &&
          task['title'] is String &&
          (task['title'] as String).trim().isNotEmpty) {
        return AssistantMessageModel(
          role: 'assistant',
          content: '',
          attachmentMessage: warning.isEmpty ? null : warning,
          attachments: reports,
          draft: AssistantDraftDto.fromJson({
            ...Map<String, dynamic>.from(task),
            'resolvedAssigneeId': result['resolvedAssigneeId'],
          }).toEntity(),
        );
      }
      if (reports.isNotEmpty &&
          reports.every((e) => e.status == 'unsupported')) {
        return AssistantMessageModel(
          role: 'assistant',
          attachments: reports,
          content: warning.isNotEmpty
              ? warning
              : 'Не удалось прочитать вложения. Посмотрите причины у файлов.',
        );
      }
      return null;
    } on DioException catch (error) {
      throw AssistantException(assistantApiError(error));
    }
  }

  static bool validDraftEdit(AssistantDraft draft, String workspaceId) =>
      draft.previous?.hasValidValues != false &&
      validEdit(AssistantDraftDto.fromEntity(draft).toJson(), workspaceId);
  Future<void> applyDraft(String workspaceId, AssistantDraft draft) async {
    if (!validDraftEdit(draft, workspaceId)) {
      throw const AssistantException('Некорректный черновик изменений.');
    }
    await apply(workspaceId, AssistantDraftDto.fromEntity(draft).toJson());
  }

  Future<void> createDraft(
    String workspaceId,
    String projectId,
    AssistantDraft draft,
  ) => create(
    workspaceId,
    projectId,
    AssistantDraftDto.fromEntity(draft).toJson(),
  );
  Options options(String id) => Options(headers: {'X-Workspace-Id': id});
  Future<Map<String, dynamic>?> extract(
    String workspaceId,
    String text,
    List<String> images,
    String? projectId, {
    AssistantRequest? request,
  }) async {
    await checkWorkspace(workspaceId);
    final result = body(
      (await dio.post<dynamic>(
        'ai/extract-task',
        cancelToken: assistantCancelToken(request),
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
