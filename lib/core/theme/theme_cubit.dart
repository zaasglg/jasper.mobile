import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._preferences) : super(_read(_preferences)) {
    _persistedMode = state;
  }

  static const preferenceKey = 'appearance.themeMode';
  final SharedPreferences _preferences;

  static ThemeMode _read(SharedPreferences preferences) {
    final name = preferences.getString(preferenceKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  late ThemeMode _persistedMode;

  Future<void> _writes = Future<void>.value();

  Future<void> select(ThemeMode mode) {
    if (isClosed) return Future<void>.value();
    // Appearance remains usable even if device storage is temporarily unavailable.
    emit(mode);
    final operation = _writes.then((_) async {
      if (isClosed || mode == _persistedMode) return;
      if (!await _preferences.setString(preferenceKey, mode.name)) {
        throw StateError('Не удалось сохранить тему');
      }
      _persistedMode = mode;
    });
    // Keep rapid changes in tap order, and allow retry after a failed write.
    _writes = operation.catchError((Object _) {});
    return operation;
  }
}
