import '../storage/workspace_selection_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/auth_token_storage.dart';
import 'api_constants.dart';
import 'auth_interceptor.dart';

Dio createDio(
  AuthTokenStorage tokenStorage, {
  WorkspaceSelectionStorage? workspaceStorage,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: const <String, dynamic>{'Accept': Headers.jsonContentType},
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(tokenStorage, workspaceStorage: workspaceStorage),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        requestHeader: false,
        responseHeader: false,
        logPrint: (value) {
          const maxLength = 2000;
          final message = value.toString();
          debugPrint(
            message.length > maxLength
                ? '${message.substring(0, maxLength)}\n…[лог сокращён]'
                : message,
          );
        },
      ),
    );
  }

  return dio;
}
