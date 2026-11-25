import '../domain/notification_preferences_repository.dart';
import 'dart:async';
import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/storage/auth_token_storage.dart';
import '../data/mobile_push_registration.dart';
import '../domain/entities/notification_preferences.dart';
import 'push_cubit.dart';

class NotificationPreferencesState extends Equatable {
  const NotificationPreferencesState({
    this.value = const NotificationPreferences(),
    this.owner,
    this.saving = false,
    this.error,
  });
  final NotificationPreferences value;
  final String? owner, error;
  final bool saving;
  @override
  List<Object?> get props => [value, owner, saving, error];
}

class NotificationPreferencesCubit extends Cubit<NotificationPreferencesState>
    with WidgetsBindingObserver {
  NotificationPreferencesCubit(this.repository, this.tokens, this.push)
    : super(const NotificationPreferencesState());
  final NotificationPreferencesRepository repository;
  final AuthTokenStorage tokens;
  final PushCubit push;
  StreamSubscription<PushState>? _subscription;
  bool _started = false;
  int _revision = 0;
  Future<void> _syncWrites = Future.value();
  String? _lastSyncedKey;
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    authSession.addListener(_authChanged);
    _subscription = push.stream.listen((next) {
      if (!state.saving && next.registered && next.token != null) {
        unawaited(synchronize());
      }
    });
    unawaited(load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(synchronize());
  }

  void _authChanged() => unawaited(load());
  Future<void> load() async {
    final revision = ++_revision;
    _lastSyncedKey = null;
    String? jwt;
    try {
      jwt = await tokens.read();
    } catch (_) {
      if (!isClosed && revision == _revision) {
        emit(
          const NotificationPreferencesState(
            error: 'Не удалось загрузить настройки уведомлений.',
          ),
        );
      }
      return;
    }
    if (isClosed || revision != _revision) return;
    final owner = authSession.requiresLogin || jwt == null
        ? null
        : pushAccountId(jwt);
    final value = owner == null
        ? const NotificationPreferences()
        : repository.read(owner);
    emit(NotificationPreferencesState(owner: owner, value: value));
    if (owner != null) await synchronize();
  }

  Future<void> update(NotificationPreferences value) async {
    final owner = state.owner;
    if (owner == null ||
        state.saving ||
        isClosed ||
        authSession.requiresLogin ||
        pushAccountId(tokens.cachedToken ?? '') != owner) {
      return;
    }
    final revision = ++_revision;
    emit(
      NotificationPreferencesState(
        owner: owner,
        value: state.value,
        saving: true,
      ),
    );
    try {
      await repository.save(owner, value);
      if (isClosed || revision != _revision) return;
      emit(NotificationPreferencesState(owner: owner, value: value));
      await synchronize();
    } catch (_) {
      if (!isClosed && revision == _revision) {
        emit(
          NotificationPreferencesState(
            owner: owner,
            value: state.value,
            error: 'Не удалось сохранить настройки уведомлений.',
          ),
        );
      }
    }
  }

  Future<void> synchronize() {
    final operation = _syncWrites.then((_) => _synchronize());
    _syncWrites = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _synchronize() async {
    final snapshot = state;
    final jwt = tokens.cachedToken;
    final revision = _revision;
    if (snapshot.owner == null ||
        jwt == null ||
        authSession.requiresLogin ||
        pushAccountId(jwt) != snapshot.owner ||
        !push.state.supported) {
      return;
    }
    final data = {
      ...snapshot.value.toJson(),
      'utcOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
    };
    final deviceToken = push.state.token;
    try {
      data['timeZone'] = await repository.applyNative(snapshot.owner!, data);
      final key = '$jwt:$deviceToken:${jsonEncode(data)}';
      if (key == _lastSyncedKey) return;
      if (isClosed || revision != _revision || tokens.cachedToken != jwt) {
        return;
      }
      if (!push.state.registered || push.state.token == null) return;
      await repository.synchronize(jwt, deviceToken!, data);
      if (!isClosed && revision == _revision) {
        _lastSyncedKey = key;
        emit(
          NotificationPreferencesState(
            owner: snapshot.owner,
            value: snapshot.value,
          ),
        );
      }
    } catch (_) {
      if (!isClosed && revision == _revision) {
        emit(
          NotificationPreferencesState(
            owner: snapshot.owner,
            value: snapshot.value,
            error:
                'Настройки сохранены на устройстве. Не удалось синхронизировать фоновые уведомления.',
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    ++_revision;
    if (_started) {
      authSession.removeListener(_authChanged);
      WidgetsBinding.instance.removeObserver(this);
    }
    await _subscription?.cancel();
    await super.close();
  }
}
