import 'package:dio/dio.dart';

import '../storage/auth_token_storage.dart';

class UserAvatarRepository {
  UserAvatarRepository(this._dio, this._tokens);
  final Dio _dio;
  final AuthTokenStorage _tokens;
  final _pending = <String, Future<String?>>{};
  String? _session;

  Future<String?> avatarFor(String userId) {
    if (_session != _tokens.cachedToken) {
      _pending.clear();
      _session = _tokens.cachedToken;
    }
    return _pending.putIfAbsent(userId, () => _load(userId));
  }

  Future<String?> _load(String userId) async {
    try {
      final response = await _dio.get<dynamic>(
        'users/${Uri.encodeComponent(userId)}',
      );
      dynamic value = response.data;
      if (value is Map) value = value['data'] ?? value['user'] ?? value;
      if (value is! Map) return null;
      final avatar =
          value['avatarUrl'] ?? value['avatar_url'] ?? value['avatar'];
      return avatar is String && avatar.trim().isNotEmpty ? avatar : null;
    } catch (_) {
      _pending.remove(userId);
      return null;
    }
  }
}
