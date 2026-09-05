import '../entities/task_extra_field.dart';

abstract interface class MyTaskFieldsStorage {
  Future<Set<TaskExtraField>> read();

  Future<void> save(Set<TaskExtraField> fields);
}
