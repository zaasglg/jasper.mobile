import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The website also keeps read state locally; scope it to account and workspace.
class MentionsReadStorage {
  const MentionsReadStorage(this.storage);
  final FlutterSecureStorage storage;
  String _key(String userId, String workspaceId) =>
      'mentions_read:${Uri.encodeComponent(userId)}:${Uri.encodeComponent(workspaceId)}';
  Future<Set<String>> load(String userId, String workspaceId) async {
    final raw = await storage.read(key: _key(userId, workspaceId));
    if (raw == null) return {};
    try {
      final value = jsonDecode(raw);
      return value is List ? value.whereType<String>().toSet() : {};
    } on FormatException {
      return {};
    }
  }

  Future<void> save(String userId, String workspaceId, Set<String> ids) async {
    final values = ids.toList()..sort();
    await storage.write(
      key: _key(userId, workspaceId),
      value: jsonEncode(values),
    );
  }
}
