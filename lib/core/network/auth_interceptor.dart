import 'package:dio/dio.dart';

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
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }
}
