import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/auth/data/models/login_request.dart';
import 'package:jospar/features/auth/data/google_auth_browser.dart';
import 'package:jospar/features/auth/data/repositories/auth_repository_impl.dart';

class _PendingApi {
  final dio = Dio();
  final requests =
      <String, Completer<(RequestOptions, RequestInterceptorHandler)>>{};

  _PendingApi() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          final key = request.path == 'auth/login'
              ? request.data['email'] as String
              : request.path;
          requests.putIfAbsent(key, Completer.new).complete((request, handler));
        },
      ),
    );
  }

  Future<void> respond(String key, [String? token]) async {
    final (request, handler) = await requests
        .putIfAbsent(key, Completer.new)
        .future;
    handler.resolve(
      Response(
        requestOptions: request,
        statusCode: 200,
        data: token == null ? <String, dynamic>{} : {'access_token': token},
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'late Google callback cannot replace a newer password session',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'selected_workspace_id': 'current-workspace',
      });
      const secure = FlutterSecureStorage();
      final tokens = AuthTokenStorage(secure);
      final api = _PendingApi();
      addTearDown(api.dio.close);
      final browserUrl = Completer<String>();
      final callback = Completer<String>();
      final repository = AuthRepositoryImpl(
        dio: api.dio,
        storage: tokens,
        workspaceSelectionStorage: const WorkspaceSelectionStorage(secure),
        googleBrowser: GoogleAuthBrowser(
          authenticate: (url) {
            browserUrl.complete(url);
            return callback.future;
          },
        ),
      );
      final older = repository.loginWithGoogle();
      final rejected = expectLater(older, throwsA(isA<AuthException>()));
      final url = Uri.parse(await browserUrl.future);
      const request = LoginRequest(
        email: 'current@jospar.me',
        password: 'secret',
      );
      final newer = repository.login(request);
      await api.respond(request.email, 'current-token');
      await newer;
      callback.complete(
        Uri(
          scheme: 'com.jospar.app',
          host: 'oauth',
          path: '/google',
          queryParameters: {
            'state': url.queryParameters['app_state']!,
            'code': 'old-code',
          },
        ).toString(),
      );
      await rejected;
      expect(await tokens.read(), 'current-token');
      expect(
        await secure.read(key: 'selected_workspace_id'),
        'current-workspace',
      );
      expect(api.requests.containsKey('auth/google/mobile/exchange'), isFalse);
    },
  );

  for (final scenario in ['login-login', 'login-logout', 'logout-login']) {
    test('latest auth request wins: $scenario', () async {
      FlutterSecureStorage.setMockInitialValues({'access_token': 'original'});
      const secure = FlutterSecureStorage();
      final tokens = AuthTokenStorage(secure);
      final api = _PendingApi();
      addTearDown(api.dio.close);
      final repository = AuthRepositoryImpl(
        dio: api.dio,
        storage: tokens,
        workspaceSelectionStorage: const WorkspaceSelectionStorage(secure),
      );
      const first = LoginRequest(email: 'first@jospar.me', password: 'secret');
      const second = LoginRequest(
        email: 'second@jospar.me',
        password: 'secret',
      );
      final older = scenario == 'logout-login'
          ? repository.logout()
          : repository.login(first);
      final rejected = expectLater(older, throwsA(isA<AuthException>()));
      if (scenario == 'login-logout') {
        final newer = repository.logout();
        await api.respond('auth/logout');
        await newer;
        await api.respond(first.email, 'stale');
        await rejected;
        expect(await tokens.read(), isNull);
      } else {
        final newer = repository.login(second);
        await api.respond(second.email, 'new-session');
        await newer;
        await api.respond(
          scenario == 'logout-login' ? 'auth/logout' : first.email,
          scenario == 'logout-login' ? null : 'stale',
        );
        await rejected;
        expect(await tokens.read(), 'new-session');
      }
      expect(await secure.read(key: 'access_token'), await tokens.read());
    });
  }
}
