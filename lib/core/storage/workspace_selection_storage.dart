import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WorkspaceSelectionStorage {
  const WorkspaceSelectionStorage(this._storage);

  static const String _selectedWorkspaceKey = 'selected_workspace_id';

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _selectedWorkspaceKey);

  Future<void> save(String workspaceId) {
    return _storage.write(key: _selectedWorkspaceKey, value: workspaceId);
  }

  Future<void> clear() => _storage.delete(key: _selectedWorkspaceKey);
}
