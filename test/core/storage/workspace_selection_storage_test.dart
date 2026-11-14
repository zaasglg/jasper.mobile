import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all readers see latest selection before queued writes complete',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'selected_workspace_id': 'old',
      });
      const storage = WorkspaceSelectionStorage(FlutterSecureStorage());
      final first = storage.stageSelection('first');
      expect(await storage.read(), 'first');
      final latest = storage.stageSelection('latest');
      await storage.save('first');
      storage.finishSelection(first);
      expect(await storage.read(), 'latest');
      await storage.save('latest');
      storage.finishSelection(latest);
      expect(await storage.read(), 'latest');
      final cleared = storage.stageSelection(null);
      expect(await storage.read(), isNull);
      await storage.clear();
      storage.finishSelection(cleared);
      expect(await storage.read(), isNull);
    },
  );
}
