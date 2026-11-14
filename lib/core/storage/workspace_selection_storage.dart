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

  Future<void> clear() => _storage.delete(key: _selectedWorkspaceKey);
}

class _PendingSelection {
  _PendingSelection(this.id);
  final String? id;
}
