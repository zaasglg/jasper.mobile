import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/task_extra_field.dart';
import '../../domain/repositories/my_task_fields_storage.dart';

class MyTaskFieldsStorageImpl implements MyTaskFieldsStorage {
  const MyTaskFieldsStorageImpl(this._storage);

  static const String _key = 'dashboard_my_task_fields';
  final FlutterSecureStorage _storage;

  @override
  Future<Set<TaskExtraField>> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return TaskExtraField.values.toSet();
    final names = value.split(',').toSet();
    return TaskExtraField.values
        .where((field) => names.contains(field.name))
        .toSet();
  }

  @override
  Future<void> save(Set<TaskExtraField> fields) {
    final value = TaskExtraField.values
        .where(fields.contains)
        .map((field) => field.name)
        .join(',');
    return _storage.write(key: _key, value: value);
  }
}
