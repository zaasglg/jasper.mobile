import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:jospar/features/auth/domain/entities/login_request.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'password login posts the original credential JSON and saves token',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const secure = FlutterSecureStorage();
      final storage = AuthTokenStorage(secure);
      final dio = Dio();
      addTearDown(dio.close);
      RequestOptions? sent;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            sent = request;
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {'access_token': 'password-token'},
              ),
            );
          },
        ),
      );
      final repository = AuthRepositoryImpl(
        dio: dio,
        storage: storage,
        workspaceSelectionStorage: const WorkspaceSelectionStorage(secure),
      );

      final token = await repository.login(
        const LoginRequest(email: 'user@jospar.me', password: ' secret '),
      );

      expect(sent?.method, 'POST');
      expect(sent?.path, 'auth/login');
      expect(sent?.data, {'email': 'user@jospar.me', 'password': ' secret '});
      expect(token, 'password-token');
      expect(await storage.read(), token);
    },
  );
}
