import 'dart:async';
import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_session.dart';
import '../storage/auth_token_storage.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';

class AppLocaleState extends Equatable {
  const AppLocaleState({
    this.code = 'ru',
    this.owner,
    this.saving = false,
    this.error,
  });
  final String code;
  final String? owner, error;
  final bool saving;
  @override
  List<Object?> get props => [code, owner, saving, error];
}

class LocaleCubit extends Cubit<AppLocaleState> {
  LocaleCubit(
    this._profiles,
    this._writer,
    this._preferences,
    this._tokens, {
    AuthSession? session,
  }) : _session = session ?? authSession,
       super(
         AppLocaleState(
           code: _valid(_preferences.getString('ui_locale.guest')),
         ),
       ) {
    _session.addListener(_onAuth);
  }
  final ProfileRepository _profiles;
  final ProfileLocaleRepository _writer;
  final SharedPreferences _preferences;
  final AuthTokenStorage _tokens;
  final AuthSession _session;
  int _revision = 0;
  static String _valid(String? value) => value == 'kk' ? 'kk' : 'ru';
  String? _owner(String? token) {
    try {
      if (token == null) return null;
      final json = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      );
      final id = json is Map ? json['sub'] ?? json['id'] : null;
      return id is String && id.isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
  }

  void _onAuth() {
    _revision++;
    if (isClosed) return;
    emit(
      AppLocaleState(code: _valid(_preferences.getString('ui_locale.guest'))),
    );
    unawaited(refresh());
  }

  bool _current(int revision, int generation) =>
      !isClosed && revision == _revision && generation == _session.generation;

  Future<void> refresh() async {
    if (isClosed || state.saving) return;
    final revision = ++_revision, generation = _session.generation;
    if (_session.requiresLogin) {
      emit(
        AppLocaleState(code: _valid(_preferences.getString('ui_locale.guest'))),
      );
      return;
    }
    final token = await _tokens.read();
    if (!_current(revision, generation)) return;
    final owner = _owner(token);
    emit(
      AppLocaleState(
        code: _valid(
          _preferences.getString(
            owner == null ? 'ui_locale.guest' : 'ui_locale.$owner',
          ),
        ),
        owner: owner,
      ),
    );
    if (token == null || token.isEmpty) return;
    try {
      final profile = await _profiles.getCurrentUser();
      final activeToken = await _tokens.read();
      if (!_current(revision, generation) || activeToken != token) {
        return;
      }
      if (owner != null && profile.id != owner) return;
      if (profile.id.isEmpty) return;
      final code = _valid(profile.locale);
      emit(AppLocaleState(code: code, owner: profile.id));
      await _preferences.setString('ui_locale.${profile.id}', code);
    } catch (_) {
      // Retain this account's cached language while offline.
    }
  }

  Future<void> select(String code) async {
    if (isClosed || state.saving || !['ru', 'kk'].contains(code)) return;
    final previous = state;
    if (previous.code == code) return;
    final revision = ++_revision, generation = _session.generation;
    emit(
      AppLocaleState(code: previous.code, owner: previous.owner, saving: true),
    );
    try {
      final token = await _tokens.read();
      if (!_current(revision, generation)) return;
      if (token == null || token.isEmpty || _session.requiresLogin) {
        await _preferences.setString('ui_locale.guest', code);
        if (_current(revision, generation)) emit(AppLocaleState(code: code));
        return;
      }
      final owner = _owner(token) ?? previous.owner;
      final profile = await _writer.updateLocale(code);
      final activeToken = await _tokens.read();
      if (!_current(revision, generation) || activeToken != token) {
        return;
      }
      if (profile.id.isEmpty ||
          (owner != null && profile.id != owner) ||
          profile.locale != code) {
        throw StateError('Mismatched profile');
      }
      emit(AppLocaleState(code: code, owner: profile.id));
      try {
        await _preferences.setString('ui_locale.${profile.id}', code);
      } catch (_) {
        /* Server remains authoritative. */
      }
    } catch (_) {
      if (_current(revision, generation)) {
        emit(
          AppLocaleState(
            code: previous.code,
            owner: previous.owner,
            error: 'Не удалось сохранить язык. Попробуйте ещё раз.',
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _revision++;
    _session.removeListener(_onAuth);
    return super.close();
  }
}
