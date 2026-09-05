import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/tasks/data/storage/my_task_fields_storage_impl.dart';
import 'package:jospar/features/tasks/domain/entities/task_extra_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'enables every field by default and persists a custom selection',
    () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      const storage = MyTaskFieldsStorageImpl(FlutterSecureStorage());

      expect(await storage.read(), TaskExtraField.values.toSet());

      await storage.save(<TaskExtraField>{
        TaskExtraField.id,
        TaskExtraField.epics,
      });

      expect(await storage.read(), <TaskExtraField>{
        TaskExtraField.id,
        TaskExtraField.epics,
      });
    },
  );
}
