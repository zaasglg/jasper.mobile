import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/auth/data/apple_auth_provider.dart';
import 'package:jospar/features/auth/data/models/apple_sign_in_credential.dart';
import 'package:jospar/features/auth/data/repositories/auth_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exchanges Apple credential and persists server session', () async {
    FlutterSecureStorage.setMockInitialValues({
      'selected_workspace_id': 'old-workspace',
    });
    const secure = FlutterSecureStorage();
    final tokens = AuthTokenStorage(secure);
    final workspace = WorkspaceSelectionStorage(secure);
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(request.path, 'auth/apple/mobile/exchange');
            expect(request.data, <String, dynamic>{
              'authorizationCode': 'authorization-code',
              'identityToken': 'identity-token',
              'rawNonce': 'raw-nonce',
              'userIdentifier': 'apple-user-id',
              'email': 'user@privaterelay.appleid.com',
              'givenName': 'Jospar',
              'familyName': 'User',
            });
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
      appleAuthProvider: const _FakeAppleAuthProvider(),
    );

    expect(await repository.loginWithApple(), 'server-session');
    expect(await tokens.read(), 'server-session');
    expect(await workspace.read(), isNull);
  });

  test('cancelled Apple authorization does not call the API', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const secure = FlutterSecureStorage();
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (_, handler) =>
              fail('API must not be called after cancel'),
        ),
      );
    addTearDown(dio.close);
    final repository = AuthRepositoryImpl(
      dio: dio,
      storage: AuthTokenStorage(secure),
      workspaceSelectionStorage: const WorkspaceSelectionStorage(secure),
      appleAuthProvider: const _CancelledAppleAuthProvider(),
    );

    expect(await repository.loginWithApple(), isNull);
  });
}

class _FakeAppleAuthProvider implements AppleAuthProvider {
  const _FakeAppleAuthProvider();

  @override
  Future<AppleSignInCredential?> authorize() async {
    return const AppleSignInCredential(
      authorizationCode: 'authorization-code',
      identityToken: 'identity-token',
      rawNonce: 'raw-nonce',
      userIdentifier: 'apple-user-id',
      email: 'user@privaterelay.appleid.com',
      givenName: 'Jospar',
      familyName: 'User',
    );
  }
}

class _CancelledAppleAuthProvider implements AppleAuthProvider {
  const _CancelledAppleAuthProvider();

  @override
  Future<AppleSignInCredential?> authorize() async => null;
}
