import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokenStorage {
  AuthTokenStorage(this._storage);

  static const String _accessTokenKey = 'access_token';

  final FlutterSecureStorage _storage;
  String? _cachedToken;
  bool _hasReadToken = false;
  Future<void> _pending = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  String? get cachedToken => _cachedToken;

  Future<String?> read() => _serialize(() async {
    if (_hasReadToken) return _cachedToken;
    _cachedToken = await _storage.read(key: _accessTokenKey);
    _hasReadToken = true;
    return _cachedToken;
  });

  Future<void> save(String token) => _serialize(() async {
    await _storage.write(key: _accessTokenKey, value: token);
    _cachedToken = token;
    _hasReadToken = true;
  });

  /// Keeps a superseded login from publishing a token, even if a newer auth
  /// operation starts while the platform secure-storage write is pending.
  Future<bool> saveIfCurrent(String token, bool Function() isCurrent) =>
      _serialize(() async {
        if (!isCurrent()) return false;
        final previous = _hasReadToken
            ? _cachedToken
            : await _storage.read(key: _accessTokenKey);
        if (!isCurrent()) return false;
        await _storage.write(key: _accessTokenKey, value: token);
        if (!isCurrent()) {
          if (previous == null) {
            await _storage.delete(key: _accessTokenKey);
          } else {
            await _storage.write(key: _accessTokenKey, value: previous);
          }
          return false;
        }
        _cachedToken = token;
        _hasReadToken = true;
        return true;
      });

  Future<void> clear() => _serialize(_clear);

  Future<void> _clear() async {
    _cachedToken = null;
    _hasReadToken = true;
    await _storage.delete(key: _accessTokenKey);
  }

  /// Compares and clears in the same storage queue as login writes.
  Future<bool> clearIfMatches(String rejectedToken) => _serialize(() async {
    final current = _hasReadToken
        ? _cachedToken
        : await _storage.read(key: _accessTokenKey);
    String normalize(String value) => value
        .replaceFirst(RegExp(r'^bearer\s+', caseSensitive: false), '')
        .trim();
    if (current == null || normalize(current) != normalize(rejectedToken)) {
      return false;
    }
    try {
      await _clear();
    } catch (_) {
      // Memory must still reject the expired session if secure deletion fails.
    }
    return true;
  });
}
