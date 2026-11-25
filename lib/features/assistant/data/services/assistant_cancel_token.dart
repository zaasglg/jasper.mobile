import 'dart:async';
import 'package:dio/dio.dart';
import '../../domain/entities/assistant_request.dart';

CancelToken? assistantCancelToken(AssistantRequest? request) {
  if (request == null) return null;
  final token = CancelToken();
  if (request.isCancelled) {
    token.cancel('Stopped by user');
  } else {
    unawaited(
      request.whenCancelled.then((_) => token.cancel('Stopped by user')),
    );
  }
  return token;
}
