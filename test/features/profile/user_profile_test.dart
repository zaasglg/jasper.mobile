import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/profile/domain/entities/user_profile.dart';

void main() {
  test('preserves roles through serialization and translates known roles', () {
    for (final entry in {
      'SUPER_ADMIN': 'Суперадмин',
      'ADMIN': 'Админ',
      'EXECUTOR': 'Участник',
      'OWNER': 'Владелец',
      'CUSTOM': 'CUSTOM',
      '': 'Не указана',
    }.entries) {
      final profile = UserProfile(id: '', name: '', email: '', role: entry.key);
      expect(profile.roleLabel, entry.value);
      expect(profile.copyWith(name: 'Новое имя').role, entry.key);
    }
  });
}
