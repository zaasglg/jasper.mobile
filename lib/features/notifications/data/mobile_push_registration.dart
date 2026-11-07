import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/storage/auth_token_storage.dart';
import '../presentation/push_cubit.dart';

String? pushAccountId(String token) {
  try {
    final value = token.replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    );
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(value.split('.')[1]))),
    );
    return claims is Map && claims['sub'] is String
        ? claims['sub'] as String
        : null;
  } catch (_) {
    return null;
  }
}

/// Registration is session-bound on the server. Never send a client userId.
class MobilePushRegistration {
  MobilePushRegistration(this.dio, this.storage, this.cubit);
  final Dio dio;
  final AuthTokenStorage storage;
  final PushCubit cubit;
  CancelToken? _request;
  StreamSubscription<PushState>? _subscription;
  String? _registeredKey, _inFlightKey;
  int _revision = 0;
  void start() {
    if (_subscription != null) return;
    PushState? previous;
    _subscription ??= cubit.stream.listen((state) {
      final changed =
          previous == null ||
          previous!.token != state.token ||
          previous!.authorized != state.authorized ||
          previous!.channelEnabled != state.channelEnabled ||
          (previous!.loading && !state.loading);
      previous = state;
      if (changed && !state.loading && state.token != null) {
        unawaited(synchronize());
      }
    });
    authSession.addListener(_authChanged);
  }

  Future<void> dispose() async {
    ++_revision;
    _request?.cancel();
    authSession.removeListener(_authChanged);
    await _subscription?.cancel();
    _subscription = null;
  }

  void _authChanged() {
    if (authSession.requiresLogin) {
      ++_revision;
      _request?.cancel();
      _registeredKey = null;
      _inFlightKey = null;
      cubit.registrationStatus(false);
    } else {
      unawaited(synchronize());
    }
  }

  Future<void> synchronize() async {
    if (!cubit.state.supported ||
        !cubit.state.authorized ||
        !cubit.state.channelEnabled ||
        authSession.requiresLogin) {
      return;
    }
    final token = cubit.state.token;
    if (token == null) return;
    final jwt = await storage.read();
    if (jwt == null || jwt.isEmpty) return;
    final userId = pushAccountId(jwt);
    if (userId == null) return;
    final key = '$jwt:$token';
    if (key == _registeredKey || key == _inFlightKey) return;
    final revision = ++_revision;
    _request?.cancel();
    final request = CancelToken();
    _request = request;
    _inFlightKey = key;
    try {
      await cubit.gateway.bindAccount(userId);
      if (storage.cachedToken != jwt || revision != _revision) return;
      await dio.post<dynamic>(
        'push/mobile/devices',
        data: {
          'token': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        },
        cancelToken: request,
      );
      if (revision == _revision && storage.cachedToken == jwt) {
        _registeredKey = key;
        cubit.registrationStatus(true);
      }
    } catch (error) {
      if (revision == _revision &&
          !(error is DioException && CancelToken.isCancel(error))) {
        cubit.registrationStatus(
          false,
          error:
              'Подключение уведомлений не завершено. Повторите проверку позже.',
        );
      }
    } finally {
      if (revision == _revision) _inFlightKey = null;
    }
  }
}
