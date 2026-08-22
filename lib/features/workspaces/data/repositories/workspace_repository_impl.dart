import 'package:dio/dio.dart';

import '../../domain/repositories/workspace_repository.dart';
import '../models/create_workspace_request.dart';
import '../models/workspace_model.dart';

class WorkspaceRepositoryImpl implements WorkspaceRepository {
  const WorkspaceRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<WorkspaceModel>> getWorkspaces() async {
    try {
      final response = await _dio.get<dynamic>('workspaces');
      final items = _unwrapItems(response.data);
      return items
          .whereType<Map>()
          .map(
            (item) => WorkspaceModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((workspace) => workspace.id.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      throw WorkspaceException(_messageForDioError(error));
    } on WorkspaceException {
      rethrow;
    } catch (_) {
      throw const WorkspaceException('Не удалось загрузить workspace.');
    }
  }

  @override
  Future<WorkspaceModel> createWorkspace(CreateWorkspaceRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        'workspaces',
        data: request.toJson(),
      );
      final payload = _unwrapWorkspace(response.data);
      final parsed = WorkspaceModel.fromJson(payload);
      if (parsed.id.isEmpty) {
        throw const WorkspaceException('Сервер не вернул созданный workspace.');
      }
      return parsed.copyWith(
        name: parsed.name.trim().isEmpty ? request.name : parsed.name,
        color: parsed.color?.trim().isEmpty ?? true
            ? request.color
            : parsed.color,
      );
    } on DioException catch (error) {
      throw WorkspaceException(_messageForCreateError(error));
    } on WorkspaceException {
      rethrow;
    } catch (_) {
      throw const WorkspaceException('Не удалось создать workspace.');
    }
  }

  List<dynamic> _unwrapItems(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final payload = Map<String, dynamic>.from(data);
      for (final key in const <String>['data', 'workspaces', 'items']) {
        final value = payload[key];
        if (value is List) return value;
      }
    }
    throw const WorkspaceException('Сервер вернул некорректный список.');
  }

  Map<String, dynamic> _unwrapWorkspace(dynamic data) {
    if (data is! Map) {
      throw const WorkspaceException('Сервер вернул некорректные данные.');
    }
    final payload = Map<String, dynamic>.from(data);
    for (final key in const <String>['data', 'workspace']) {
      final value = payload[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return payload;
  }

  String _messageForCreateError(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map) {
      final rawMessage = responseData['message'];
      if (rawMessage is String && rawMessage.trim().isNotEmpty) {
        return rawMessage.trim();
      }
      if (rawMessage is List && rawMessage.isNotEmpty) {
        return rawMessage.first.toString();
      }
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return 'Сервер не отвечает. Попробуйте ещё раз.';
      case DioExceptionType.connectionError:
        return 'Нет подключения к интернету.';
      case DioExceptionType.badResponse:
        if (error.response?.statusCode == 401 ||
            error.response?.statusCode == 403) {
          return 'Сессия истекла. Войдите снова.';
        }
        return 'Не удалось создать workspace.';
      case DioExceptionType.cancel:
        return 'Запрос был отменён.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return 'Не удалось подключиться к серверу.';
    }
  }

  String _messageForDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return 'Сервер не отвечает. Попробуйте ещё раз.';
      case DioExceptionType.connectionError:
        return 'Нет подключения к интернету.';
      case DioExceptionType.badResponse:
        if (error.response?.statusCode == 401 ||
            error.response?.statusCode == 403) {
          return 'Сессия истекла. Войдите снова.';
        }
        return 'Не удалось загрузить workspace.';
      case DioExceptionType.cancel:
        return 'Запрос был отменён.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return 'Не удалось подключиться к серверу.';
    }
  }
}

class WorkspaceException implements Exception {
  const WorkspaceException(this.message);

  final String message;

  @override
  String toString() => message;
}
