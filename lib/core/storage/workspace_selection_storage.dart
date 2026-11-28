import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WorkspaceSelectionStorage {
  const WorkspaceSelectionStorage(this._storage);

  static const String _selectedWorkspaceKey = 'selected_workspace_id';

  final FlutterSecureStorage _storage;

  // Expose a selection immediately while its secure-storage write is queued.
  static final _pendingSelections = Expando<_PendingSelection>();

  Object stageSelection(String? id) {
    final selection = _PendingSelection(id);
    _pendingSelections[this] = selection;
    return selection;
  }

  void finishSelection(Object selection) {
    if (identical(_pendingSelections[this], selection)) {
      _pendingSelections[this] = null;
    }
  }

  Future<String?> read() {
    final pending = _pendingSelections[this];
    return pending == null
        ? _storage.read(key: _selectedWorkspaceKey)
        : Future.value(pending.id);
  }

  Future<void> save(String workspaceId) {
    return _storage.write(key: _selectedWorkspaceKey, value: workspaceId);
  }

  Future<List<String>?> readScope() async {
    final raw = await _storage.read(key: 'selected_workspace_scope');
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      return value is List ? value.whereType<String>().toList() : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> saveScope(Iterable<String> ids) => _storage.write(
    key: 'selected_workspace_scope',
    value: jsonEncode(ids.toList()),
  );

  Future<void> clear() async {
    await _storage.delete(key: _selectedWorkspaceKey);
    await _storage.delete(key: 'selected_workspace_scope');
  }
}

class _PendingSelection {
  _PendingSelection(this.id);
  final String? id;
}
