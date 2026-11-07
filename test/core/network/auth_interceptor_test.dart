import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'dart:typed_data';
import 'dart:async';

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

  test(
    'workspace role context follows workspace switching and preserves explicit scope',
    () async {
      const secure = FlutterSecureStorage();
      final storage = AuthTokenStorage(secure);
      const selection = WorkspaceSelectionStorage(secure);
      await storage.save('token');
      await selection.save('first');
      final adapter = _StubAdapter(statusCode: 200);
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/'))
        ..httpClientAdapter = adapter
        ..interceptors.add(
          AuthInterceptor(storage, workspaceStorage: selection),
        );
      await dio.get<dynamic>('projects');
      expect(adapter.workspaceId, 'first');
      await selection.save('second');
      await dio.get<dynamic>('projects');
      expect(adapter.workspaceId, 'second');
      await dio.get<dynamic>(
        'projects',
        options: Options(headers: {'X-Workspace-Id': 'explicit'}),
      );
      expect(adapter.workspaceId, 'explicit');
    },
  );

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

  test('late old-session 401 does not erase a new login', () async {
    final storage = AuthTokenStorage(const FlutterSecureStorage());
    await storage.save('old-token');
    final started = Completer<void>();
    final response = Completer<ResponseBody>();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/'))
      ..httpClientAdapter = _DelayedAdapter(started, response)
      ..interceptors.add(AuthInterceptor(storage));
    addTearDown(dio.close);
    final pending = expectLater(
      dio.get<dynamic>('workspaces'),
      throwsA(isA<DioException>()),
    );
    await started.future;
    await storage.save('new-token');
    authSession.markAuthenticated();
    response.complete(ResponseBody.fromString('{}', 401));
    await pending;
    expect(await storage.read(), 'new-token');
    expect(authSession.requiresLogin, isFalse);
  });
}

class _DelayedAdapter implements HttpClientAdapter {
  _DelayedAdapter(this.started, this.response);
  final Completer<void> started;
  final Completer<ResponseBody> response;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    started.complete();
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({required this.statusCode});

  final int statusCode;
  String? authorization;
  String? workspaceId;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    authorization = options.headers['Authorization'] as String?;
    workspaceId = options.headers['X-Workspace-Id'] as String?;
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
