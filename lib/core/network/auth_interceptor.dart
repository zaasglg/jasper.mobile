import '../storage/workspace_selection_storage.dart';
import 'package:dio/dio.dart';

import '../auth/auth_session.dart';
import '../storage/auth_token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(
    this._tokenStorage, {
    WorkspaceSelectionStorage? workspaceStorage,
  }) : _workspaceStorage = workspaceStorage;

  final AuthTokenStorage _tokenStorage;
  final WorkspaceSelectionStorage? _workspaceStorage;

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

    final workspaceId = await _workspaceStorage?.read();
    if (workspaceId != null && workspaceId.isNotEmpty) {
      options.headers.putIfAbsent('X-Workspace-Id', () => workspaceId);
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final rejectedToken = err.requestOptions.headers['Authorization']
        ?.toString();
    final isLoginRequest = err.requestOptions.path.endsWith('auth/login');

    if (statusCode == 401 && rejectedToken != null && !isLoginRequest) {
      // A stored token can outlive the server session. Remove it immediately so
      // subsequent requests do not keep failing and let GoRouter show login.
      try {
        final cleared = await _tokenStorage.clearIfMatches(rejectedToken);
        if (cleared) authSession.markUnauthenticated();
      } catch (_) {
        // Routing to login must not be blocked by a secure-storage I/O error.
      }
    }

    handler.next(err);
  }
}
