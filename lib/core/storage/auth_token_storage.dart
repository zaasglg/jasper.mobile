import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokenStorage {
  AuthTokenStorage(this._storage);

  static const String _accessTokenKey = 'access_token';

  final FlutterSecureStorage _storage;
  String? _cachedToken;
  bool _hasReadToken = false;

  String? get cachedToken => _cachedToken;

  Future<String?> read() async {
    if (_hasReadToken) return _cachedToken;
    _cachedToken = await _storage.read(key: _accessTokenKey);
    _hasReadToken = true;
    return _cachedToken;
  }

  Future<void> save(String token) async {
    _cachedToken = token;
    _hasReadToken = true;
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<void> clear() async {
    _cachedToken = null;
    _hasReadToken = true;
    await _storage.delete(key: _accessTokenKey);
  }
}
