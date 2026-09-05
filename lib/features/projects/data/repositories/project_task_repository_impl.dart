import 'package:dio/dio.dart';

import '../../domain/repositories/project_task_repository.dart';
import '../models/project_task_model.dart';
import 'project_repository_impl.dart';

class ProjectTaskRepositoryImpl implements ProjectTaskRepository {
  const ProjectTaskRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<ProjectTaskModel>> getTasksForProjectIds(
    List<String> projectIds,
  ) async {
    final ids = projectIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const <ProjectTaskModel>[];

    try {
      final response = await _dio.get<dynamic>(
        'project-tasks',
        queryParameters: <String, dynamic>{'projectIds': ids.join(',')},
      );
      final items = _unwrapList(response.data);
      return items
          .whereType<Map>()
          .map(
            (item) =>
                ProjectTaskModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((task) => task.id.isNotEmpty && task.projectId.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ProjectException(_messageFor(error));
    } on ProjectException {
      rethrow;
    } catch (_) {
      throw const ProjectException('Не удалось загрузить задачи проектов.');
    }
  }

  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final payload = Map<String, dynamic>.from(data);
      for (final key in const <String>['data', 'tasks', 'items']) {
        final value = payload[key];
        if (value is List) return value;
        if (value is Map) {
          final nested = Map<String, dynamic>.from(value);
          for (final nestedKey in const <String>['tasks', 'items']) {
            if (nested[nestedKey] is List) return nested[nestedKey] as List;
          }
        }
      }
    }
    throw const ProjectException('Сервер вернул некорректный список задач.');
  }

  String _messageFor(DioException error) {
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
        return 'Не удалось загрузить задачи проектов.';
      case DioExceptionType.cancel:
        return 'Запрос был отменён.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return 'Не удалось подключиться к серверу.';
    }
  }
}
