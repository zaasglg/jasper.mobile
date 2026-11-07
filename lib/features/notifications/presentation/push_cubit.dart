import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/push_notification.dart';
import '../domain/push_gateway.dart';

class PushState extends Equatable {
  const PushState({
    this.supported = false,
    this.loading = false,
    this.authorized = false,
    this.channelEnabled = true,
    this.token,
    this.error,
    this.registered = false,
    this.registrationError,
  });
  final bool supported, loading, authorized, channelEnabled;
  final String? token, error, registrationError;
  final bool registered;
  PushState copyWith({
    bool? supported,
    bool? loading,
    bool? authorized,
    bool? channelEnabled,
    String? token,
    String? error,
    bool clearToken = false,
    bool? registered,
    String? registrationError,
    bool clearRegistrationError = false,
  }) => PushState(
    supported: supported ?? this.supported,
    loading: loading ?? this.loading,
    authorized: authorized ?? this.authorized,
    channelEnabled: channelEnabled ?? this.channelEnabled,
    token: clearToken ? null : token ?? this.token,
    error: error,
    registered: registered ?? this.registered,
    registrationError: clearRegistrationError
        ? null
        : registrationError ?? this.registrationError,
  );
  @override
  List<Object?> get props => [
    supported,
    loading,
    authorized,
    channelEnabled,
    token,
    error,
    registered,
    registrationError,
  ];
}

class PushCubit extends Cubit<PushState> {
  PushCubit(this.gateway) : super(PushState(supported: gateway.supported));
  final PushGateway gateway;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  int _revision = 0;
  int _tokenRevision = 0;
  Future<void> initialize({
    required void Function(PushNotificationData) onOpened,
    void Function()? onMessage,
  }) async {
    if (!gateway.supported || _subscription != null) return;
    _subscription = gateway.events.listen((event) {
      if (isClosed) return;
      if (event['kind'] == 'tokenChanged' && event['token'] is String) {
        ++_tokenRevision;
        emit(state.copyWith(token: event['token'] as String));
      }
      if (event['kind'] == 'opened' && event['data'] is Map) {
        onOpened(
          PushNotificationData.fromJson(
            Map<String, dynamic>.from(event['data'] as Map),
          ),
        );
      }
      if (event['kind'] == 'message') {
        onMessage?.call();
      }
    });
    try {
      final initial = await gateway.initialMessage();
      if (initial != null && !isClosed) {
        onOpened(PushNotificationData.fromJson(initial));
      }
    } catch (_) {
      /* Manual settings retry remains available. */
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (!gateway.supported || isClosed) return;
    final revision = ++_revision;
    emit(state.copyWith(loading: true));
    try {
      final permission = await gateway.status();
      if (isClosed || revision != _revision) return;
      emit(
        state.copyWith(
          authorized: permission['authorized'] == true,
          channelEnabled: permission['channelEnabled'] != false,
        ),
      );
      final tokenRevision = _tokenRevision;
      final token = await gateway.token();
      if (!isClosed && revision == _revision) {
        emit(
          state.copyWith(
            loading: false,
            token: tokenRevision == _tokenRevision ? token : state.token,
          ),
        );
      }
    } catch (_) {
      if (!isClosed && revision == _revision) {
        emit(
          state.copyWith(
            loading: false,
            error:
                'Не удалось проверить уведомления. Проверьте интернет и системные настройки.',
          ),
        );
      }
    }
  }

  Future<void> requestPermission() async {
    if (state.loading || !gateway.supported) return;
    try {
      await gateway.requestPermission();
      await refresh();
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            loading: false,
            error:
                'Не удалось открыть запрос разрешения. Проверьте системные настройки.',
          ),
        );
      }
    }
  }

  Future<void> openSettings() async {
    try {
      await gateway.openSettings();
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(error: 'Не удалось открыть настройки уведомлений.'),
        );
      }
    }
  }

  void registrationStatus(bool registered, {String? error}) {
    if (!isClosed) {
      emit(
        state.copyWith(
          registered: registered,
          registrationError: error,
          clearRegistrationError: error == null,
        ),
      );
    }
  }

  Future<void> revokeToken() async {
    ++_revision;
    if (!isClosed) emit(state.copyWith(clearToken: true, loading: false));
    if (gateway.supported) {
      try {
        await gateway.clearAccount();
        await gateway.deleteToken();
      } catch (_) {
        /* Backend unregistration is required for delivery guarantees. */
      }
    }
  }

  @override
  Future<void> close() async {
    ++_revision;
    await _subscription?.cancel();
    await super.close();
  }
}
