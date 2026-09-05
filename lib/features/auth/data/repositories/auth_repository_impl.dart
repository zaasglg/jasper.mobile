import 'package:dio/dio.dart';

import '../../../../core/storage/auth_token_storage.dart';
import '../../../../core/storage/workspace_selection_storage.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/login_request.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required Dio dio,
    required AuthTokenStorage storage,
    required WorkspaceSelectionStorage workspaceSelectionStorage,
  }) : _dio = dio,
       _storage = storage,
       _workspaceSelectionStorage = workspaceSelectionStorage;

  final Dio _dio;
  final AuthTokenStorage _storage;
  final WorkspaceSelectionStorage _workspaceSelectionStorage;

  @override
  Future<String> login(LoginRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        'auth/login',
        data: request.toJson(),
      );
      final token = _extractToken(response.data);
      await _storage.save(token);
      return token;
    } on DioException catch (error) {
      throw AuthException(_messageForDioError(error));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Не удалось выполнить вход. Попробуйте ещё раз.',
      );
    }
  }

  @override
  Future<void> logout() async {
    await Future.wait<void>(<Future<void>>[
      _storage.clear(),
      _workspaceSelectionStorage.clear(),
    ]);
  }

  String _extractToken(dynamic data) {
    final payload = data is Map<String, dynamic>
        ? data
        : data is Map
        ? Map<String, dynamic>.from(data)
        : null;
    final nestedData = payload?['data'];
    final nestedPayload = nestedData is Map
        ? Map<String, dynamic>.from(nestedData)
        : null;

    for (final source in <Map<String, dynamic>?>[payload, nestedPayload]) {
      if (source == null) continue;
      for (final key in const <String>[
        'accessToken',
        'access_token',
        'token',
      ]) {
        final value = source[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }

    throw const AuthException(
      'Сервер не вернул токен авторизации. Попробуйте ещё раз.',
    );
  }

  String _messageForDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return 'Сервер не отвечает. Проверьте соединение и повторите попытку.';
      case DioExceptionType.connectionError:
        return 'Нет подключения к интернету.';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          return 'Неверный email или пароль.';
        }
        if (statusCode == 400) {
          return 'Проверьте email и пароль.';
        }
        if (statusCode == 422) {
          return _serverMessage(error.response?.data) ??
              'Проверьте правильность введённых данных.';
        }
        return 'Ошибка сервера. Попробуйте позже.';
      case DioExceptionType.cancel:
        return 'Запрос был отменён.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return 'Не удалось подключиться к серверу.';
    }
  }

  String? _serverMessage(dynamic data) {
    if (data is! Map) return null;
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    return null;
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
