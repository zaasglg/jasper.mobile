import 'package:dio/dio.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/storage/auth_token_storage.dart';
import '../../../../core/storage/workspace_selection_storage.dart';
import '../../domain/repositories/auth_repository.dart';
import '../apple_auth_provider.dart';
import '../../domain/entities/login_request.dart';
import '../models/login_request_dto.dart';
import '../google_auth_browser.dart';

class AuthRepositoryImpl
    implements AuthRepository, GoogleLoginRepository, AppleLoginRepository {
  AuthRepositoryImpl({
    required Dio dio,
    required AuthTokenStorage storage,
    required WorkspaceSelectionStorage workspaceSelectionStorage,
    GoogleAuthBrowser googleBrowser = const GoogleAuthBrowser(),
    AppleAuthProvider appleAuthProvider = const NativeAppleAuthProvider(),
  }) : _dio = dio,
       _storage = storage,
       _workspaceSelectionStorage = workspaceSelectionStorage,
       _googleBrowser = googleBrowser,
       _appleAuthProvider = appleAuthProvider;

  final AppleAuthProvider _appleAuthProvider;

  final GoogleAuthBrowser _googleBrowser;
  int _revision = 0;
  Future<void> _pendingCommit = Future<void>.value();

  (int, int) _begin() => (++_revision, authSession.generation);

  bool _isCurrent((int, int) operation) =>
      operation.$1 == _revision && operation.$2 == authSession.generation;

  void _ensureCurrent((int, int) operation) {
    if (!_isCurrent(operation)) {
      throw const AuthException(
        'Сессия изменилась. Повторите вход при необходимости.',
      );
    }
  }

  Future<T> _commit<T>((int, int) operation, Future<T> Function() write) {
    final result = _pendingCommit.then((_) async {
      _ensureCurrent(operation);
      final value = await write();
      _ensureCurrent(operation);
      return value;
    });
    _pendingCommit = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<String> _saveToken((int, int) operation, String token) async {
    final saved = await _storage.saveIfCurrent(
      token,
      () => _isCurrent(operation),
    );
    if (!saved) _ensureCurrent(operation);
    return token;
  }

  @override
  Future<String?> loginWithGoogle() async {
    final operation = _begin();
    try {
      final grant = await _googleBrowser.authorize();
      _ensureCurrent(operation);
      if (grant == null) return null;
      final response = await _dio.post<dynamic>(
        'auth/google/mobile/exchange',
        data: {'code': grant.code, 'codeVerifier': grant.verifier},
      );
      final token = _extractToken(response.data);
      return await _commit(operation, () async {
        await _workspaceSelectionStorage.clear();
        return _saveToken(operation, token);
      });
    } on DioException catch (error) {
      throw AuthException(
        error.response?.statusCode == 404
            ? 'Вход Google пока недоступен на сервере. Попробуйте позже.'
            : 'Не удалось завершить вход через Google. Повторите попытку.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Не удалось войти через Google. Повторите попытку.',
      );
    }
  }

  @override
  Future<String?> loginWithApple() async {
    final operation = _begin();
    try {
      final credential = await _appleAuthProvider.authorize();
      _ensureCurrent(operation);
      if (credential == null) return null;
      final response = await _dio.post<dynamic>(
        'auth/apple/mobile/exchange',
        data: credential.toJson(),
      );
      final token = _extractToken(response.data);
      return await _commit(operation, () async {
        await _workspaceSelectionStorage.clear();
        return _saveToken(operation, token);
      });
    } on DioException catch (error) {
      throw AuthException(
        error.response?.statusCode == 404
            ? 'Вход через Apple пока недоступен на сервере. Попробуйте позже.'
            : 'Не удалось завершить вход через Apple. Повторите попытку.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Не удалось войти через Apple. Повторите попытку.',
      );
    }
  }

  final Dio _dio;
  final AuthTokenStorage _storage;
  final WorkspaceSelectionStorage _workspaceSelectionStorage;

  @override
  Future<String> login(LoginRequest request) async {
    final operation = _begin();
    try {
      final response = await _dio.post<dynamic>(
        'auth/login',
        data: LoginRequestDto.fromEntity(request).toJson(),
      );
      final token = _extractToken(response.data);
      return await _commit(operation, () => _saveToken(operation, token));
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
    final operation = _begin();
    try {
      await _dio.post<dynamic>('auth/logout');
    } on DioException {
      // Local sign-out must still work offline; push is also suppressed natively.
    } finally {
      await _commit(
        operation,
        () => Future.wait<void>(<Future<void>>[
          _storage.clear(),
          _workspaceSelectionStorage.clear(),
        ]),
      );
    }
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
