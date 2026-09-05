import 'package:dio/dio.dart';

import '../auth/auth_session.dart';
import '../storage/auth_token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage);

  final AuthTokenStorage _tokenStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.read();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] =
          token.toLowerCase().startsWith('bearer ') ? token : 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final hadAccessToken = err.requestOptions.headers['Authorization'] != null;
    final isLoginRequest = err.requestOptions.path.endsWith('auth/login');

    if (statusCode == 401 && hadAccessToken && !isLoginRequest) {
      // A stored token can outlive the server session. Remove it immediately so
      // subsequent requests do not keep failing and let GoRouter show login.
      try {
        await _tokenStorage.clear();
      } catch (_) {
        // Routing to login must not be blocked by a secure-storage I/O error.
      }
      authSession.markUnauthenticated();
    }

    handler.next(err);
  }
}
