import 'package:dio/dio.dart';

import '../../domain/repositories/project_repository.dart';
import '../models/create_project_request.dart';
import '../models/project_model.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  const ProjectRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<ProjectModel>> getProjects() async {
    try {
      final response = await _dio.get<dynamic>('projects');
      final items = _unwrapList(response.data);
      return items
          .whereType<Map>()
          .map((item) => ProjectModel.fromJson(Map<String, dynamic>.from(item)))
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
        data: request.toJson(),
      );
      final payload = _unwrapObject(response.data);
      final parsed = ProjectModel.fromJson(payload);
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
