import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/storage/auth_token_storage.dart';
import '../models/card_view_settings.dart';

class CardViewStorage {
  CardViewStorage(this._storage, {Dio? dio, AuthTokenStorage? tokenStorage})
    : _dio = dio,
      _tokenStorage = tokenStorage;
  final FlutterSecureStorage _storage;
  final Dio? _dio;
  final AuthTokenStorage? _tokenStorage;
  Future<void> _pending = Future.value();
  int _writeRevision = 0;
  static const _key = 'kanban_card_view_v1';
  bool get syncEnabled => _dio != null && _tokenStorage != null;
  Future<String?> currentUserId() => _account();
  Future<String?> _account() async {
    final token = await _tokenStorage?.read();
    if (token == null) return null;
    try {
      final claims = jsonDecode(
        utf8.decode(
          base64Url.decode(
            base64Url.normalize(
              token
                  .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
                  .split('.')[1],
            ),
          ),
        ),
      );
      return claims is Map ? claims['sub']?.toString() : null;
    } catch (_) {
      return null;
    }
  }

  Future<String> _cacheKey(String? workspaceId, String? projectId) async {
    if (!syncEnabled || workspaceId == null || projectId == null) return _key;
    return '$_key:${await _account() ?? 'guest'}:$workspaceId:$projectId';
  }

  Future<CardViewSettings> read({
    String? workspaceId,
    String? projectId,
  }) async {
    await _pending;
    final revision = _writeRevision;
    final owner = await _account();
    final key = await _cacheKey(workspaceId, projectId);
    final cached = await _storage.read(key: key);
    CardViewSettings local = const CardViewSettings();
    if (cached != null) {
      final json = jsonDecode(cached);
      if (json is Map<String, dynamic>) local = CardViewSettings.fromJson(json);
    }
    if (!syncEnabled ||
        workspaceId == null ||
        projectId == null ||
        await _account() == null) {
      return local;
    }
    try {
      if (await _storage.read(key: '$key:pending') == 'true') {
        await save(local, workspaceId: workspaceId, projectId: projectId);
        return local;
      }
      final response = await _dio!.get<dynamic>(
        'users/me/board-display',
        queryParameters: {
          'userId': owner,
          'workspaceId': workspaceId,
          'projectId': projectId,
          'view': 'kanban',
        },
      );
      final data = response.data;
      final value = data is Map ? data['value'] : null;
      if (value is! Map) return local;
      final settings = CardViewSettings(
        hidden: Set.unmodifiable(
          CardField.values.where((field) => value[_webKey(field)] == false),
        ),
      );
      if (revision == _writeRevision) {
        await _storage.write(key: key, value: jsonEncode(settings.toJson()));
      }
      return settings;
    } on DioException {
      return local;
    }
  }

  Future<void> save(
    CardViewSettings settings, {
    String? workspaceId,
    String? projectId,
  }) {
    _writeRevision++;
    final ownerFuture = _account();
    final operation = _pending.then((_) async {
      final owner = await ownerFuture;
      if (owner != await _account()) throw StateError('Аккаунт изменился.');
      final key = syncEnabled && workspaceId != null && projectId != null
          ? '$_key:${owner ?? 'guest'}:$workspaceId:$projectId'
          : _key;
      await _storage.write(key: key, value: jsonEncode(settings.toJson()));
      if (syncEnabled &&
          workspaceId != null &&
          projectId != null &&
          await _account() != null) {
        await _storage.write(key: '$key:pending', value: 'true');
        await _dio!.put<dynamic>(
          'users/me/board-display',
          data: {
            'userId': owner,
            'workspaceId': workspaceId,
            'projectId': projectId,
            'view': 'kanban',
            'value': {
              for (final field in CardField.values)
                _webKey(field): settings.shows(field),
            },
          },
        );
        await _storage.delete(key: '$key:pending');
      }
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  String _webKey(CardField field) => switch (field) {
    CardField.id => 'number',
    CardField.comments => 'discussion',
    _ => field.name,
  };
}
