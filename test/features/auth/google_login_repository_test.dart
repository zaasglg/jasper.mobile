import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/auth/data/google_auth_browser.dart';
import 'package:jospar/features/auth/data/repositories/auth_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'exchanges browser code, persists session and clears previous workspace',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'selected_workspace_id': 'old-workspace',
      });
      const secure = FlutterSecureStorage();
      final tokens = AuthTokenStorage(secure);
      final workspace = WorkspaceSelectionStorage(secure);
      String? challenge;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              expect(request.path, 'auth/google/mobile/exchange');
              expect(request.data['code'], 'one-time-code');
              final verifier = request.data['codeVerifier'] as String;
              expect(
                base64UrlEncode(
                  sha256.convert(ascii.encode(verifier)).bytes,
                ).replaceAll('=', ''),
                challenge,
              );
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {'access_token': 'server-session'},
                ),
              );
            },
          ),
        );
      addTearDown(dio.close);
      final repository = AuthRepositoryImpl(
        dio: dio,
        storage: tokens,
        workspaceSelectionStorage: workspace,
        googleBrowser: GoogleAuthBrowser(
          authenticate: (url) async {
            final query = Uri.parse(url).queryParameters;
            challenge = query['code_challenge'];
            return Uri(
              scheme: 'com.jospar.app',
              host: 'oauth',
              path: '/google',
              queryParameters: {
                'state': query['app_state']!,
                'code': 'one-time-code',
              },
            ).toString();
          },
        ),
      );
      expect(await repository.loginWithGoogle(), 'server-session');
      expect(await tokens.read(), 'server-session');
      expect(await secure.read(key: 'access_token'), 'server-session');
      expect(await workspace.read(), isNull);
    },
  );
}
