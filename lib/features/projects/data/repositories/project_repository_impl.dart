import '../models/create_project_request_dto.dart';
import '../../domain/entities/project_model.dart';
import '../models/project_dto.dart';
import '../../domain/entities/create_project_request.dart';
import 'package:dio/dio.dart';

import '../../domain/repositories/project_repository.dart';

class ProjectRepositoryImpl
    implements ProjectRepository, ScopedProjectRepository {
  const ProjectRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> setPinned(String id, bool pinned) => _changeProject(
    'projects/${Uri.encodeComponent(id)}',
    {'isPinned': pinned},
  );

  @override
  Future<void> archiveProject(String id) =>
      _changeProject('projects/${Uri.encodeComponent(id)}/archive', null);

  Future<void> _changeProject(String path, Map<String, dynamic>? data) async {
    try {
      await _dio.patch<dynamic>(path, data: data);
    } on DioException catch (error) {
      throw ProjectException(
        error.response?.statusCode == 403
            ? 'Недостаточно прав для этого действия.'
            : 'Не удалось изменить проект. Попробуйте ещё раз.',
      );
    }
  }

  @override
  Future<void> moveProject(
    String id, {
    required String workspaceId,
    String? parentId,
    String? anchorId,
    required String placement,
  }) async {
    try {
      await _dio.patch<dynamic>(
        'projects/${Uri.encodeComponent(id)}/move',
        data: {
          'workspaceId': workspaceId,
          'group': 'tree',
          'parentId': parentId,
          ...{'anchorId': ?anchorId},
          'placement': placement,
        },
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw ProjectException(
        status == 403
            ? 'Недостаточно прав для перемещения проекта.'
            : 'Не удалось переместить проект. Попробуйте ещё раз.',
      );
    }
  }

  @override
  Future<List<ProjectModel>> getProjects() => _getProjects();

  @override
  Future<List<ProjectModel>> getProjectsInWorkspace(String workspaceId) =>
      _getProjects(workspaceId);

  Future<List<ProjectModel>> _getProjects([String? workspaceId]) async {
    try {
      final response = await _dio.get<dynamic>(
        'projects',
        options: workspaceId == null
            ? null
            : Options(headers: {'X-Workspace-Id': workspaceId}),
      );
      final items = _unwrapList(response.data);
      return items
          .whereType<Map>()
          .map(
            (item) =>
                ProjectDto.fromJson(Map<String, dynamic>.from(item)).toEntity(),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw ProjectException(_messageFor(error, creating: false));
    } on ProjectException {
      rethrow;
    } catch (_) {
      throw const ProjectException('Не удалось загрузить проекты.');
    }
  }

  @override
  Future<ProjectModel> createProject(CreateProjectRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        'projects',
        data: CreateProjectRequestDto.fromEntity(request).toJson(),
      );
      final payload = _unwrapObject(response.data);
      final parsed = ProjectDto.fromJson(payload).toEntity();
      return ProjectModel(
        id: parsed.id,
        code: parsed.code.isEmpty ? request.code.trim() : parsed.code,
        name: parsed.name.isEmpty ? request.name.trim() : parsed.name,
        description: parsed.description ?? request.description?.trim(),
        workspaceId: parsed.workspaceId.isEmpty
            ? request.workspaceId
            : parsed.workspaceId,
        start: parsed.start ?? request.start,
        end: parsed.end ?? request.end,
        progress: payload['progress'] == null
            ? request.progress
            : parsed.progress,
        parentId: parsed.parentId ?? request.parentId,
        isPinned: payload['isPinned'] == null
            ? request.isPinned
            : parsed.isPinned,
        children: parsed.children,
      );
    } on DioException catch (error) {
      throw ProjectException(_messageFor(error, creating: true));
    } on ProjectException {
      rethrow;
    } catch (_) {
      throw const ProjectException('Не удалось создать проект.');
    }
  }

  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final payload = Map<String, dynamic>.from(data);
      for (final key in const <String>['data', 'projects', 'items']) {
        final value = payload[key];
        if (value is List) return value;
        if (value is Map) {
          final nested = Map<String, dynamic>.from(value);
          for (final nestedKey in const <String>['projects', 'items']) {
            if (nested[nestedKey] is List) return nested[nestedKey] as List;
          }
        }
      }
    }
    throw const ProjectException('Сервер вернул некорректный список.');
  }

  Map<String, dynamic> _unwrapObject(dynamic data) {
    if (data == null || data == '') return <String, dynamic>{};
    if (data is Map) {
      var payload = Map<String, dynamic>.from(data);
      for (final key in const <String>['data', 'project']) {
        final value = payload[key];
        if (value is Map) {
          payload = Map<String, dynamic>.from(value);
          break;
        }
      }
      return payload;
    }
    throw const ProjectException('Сервер вернул некорректный проект.');
  }

  String _messageFor(DioException error, {required bool creating}) {
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
        if (code == 400 || code == 422) {
          return 'Проверьте данные проекта и попробуйте снова.';
        }
        return creating
            ? 'Не удалось создать проект.'
            : 'Не удалось загрузить проекты.';
      case DioExceptionType.cancel:
        return 'Запрос был отменён.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return 'Не удалось подключиться к серверу.';
    }
  }
}

class ProjectException implements Exception {
  const ProjectException(this.message);

  final String message;

  @override
  String toString() => message;
}
