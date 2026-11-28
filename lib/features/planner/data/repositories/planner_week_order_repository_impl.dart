import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/storage/auth_token_storage.dart';
import '../../domain/repositories/planner_week_order_repository.dart';

class PlannerWeekOrderRepositoryImpl implements PlannerWeekOrderRepository {
  PlannerWeekOrderRepositoryImpl(this._preferences, this._tokens);
  final SharedPreferences _preferences;
  final AuthTokenStorage _tokens;
  Future<void> _writes = Future.value();

  @override
  Future<String?> scope(String viewScope) async {
    try {
      final token = await _tokens.read();
      if (token == null) return null;
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final owner = claims is Map ? claims['sub'] ?? claims['id'] : null;
      if (owner is! String || owner.trim().isEmpty) return null;
      return 'planner_week_order.v1.${Uri.encodeComponent(owner)}.${Uri.encodeComponent(viewScope)}';
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, List<String>>> load(String scope) async {
    await _writes;
    final raw = _preferences.get(scope);
    if (raw is! String) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String &&
              RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(entry.key as String) &&
              entry.value is List)
            entry.key as String: (entry.value as List)
                .whereType<String>()
                .where((id) => id.isNotEmpty)
                .toSet()
                .toList(),
      };
    } on FormatException {
      return {};
    }
  }

  @override
  Future<void> save(String scope, Map<String, List<String>> orders) {
    // Snapshot now; later UI changes must not change an enqueued write.
    final encoded = jsonEncode(orders);
    final operation = _writes.then((_) async {
      if (!await _preferences.setString(scope, encoded)) {
        throw StateError('Failed to save weekly order');
      }
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}
