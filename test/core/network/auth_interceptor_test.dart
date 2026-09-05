import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/auth/auth_session.dart';
import 'package:jospar/core/network/auth_interceptor.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    authSession.markAuthenticated();
  });

  test('adds bearer token to authenticated requests', () async {
    final storage = AuthTokenStorage(const FlutterSecureStorage());
    await storage.save('access-token');
    final adapter = _StubAdapter(statusCode: 200);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/'))
      ..httpClientAdapter = adapter
      ..interceptors.add(AuthInterceptor(storage));

    await dio.get<dynamic>('workspaces');

    expect(adapter.authorization, 'Bearer access-token');
    expect(authSession.requiresLogin, isFalse);
  });

  test('clears rejected token and invalidates session on 401', () async {
    final storage = AuthTokenStorage(const FlutterSecureStorage());
    await storage.save('expired-token');
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/'))
      ..httpClientAdapter = _StubAdapter(statusCode: 401)
      ..interceptors.add(AuthInterceptor(storage));

    await expectLater(
      dio.get<dynamic>('workspaces'),
      throwsA(isA<DioException>()),
    );

    expect(await storage.read(), isNull);
    expect(authSession.requiresLogin, isTrue);
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({required this.statusCode});

  final int statusCode;
  String? authorization;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    authorization = options.headers['Authorization'] as String?;
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
