import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/profile/data/models/user_profile.dart';

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
      final profile = UserProfile.fromJson({'role': entry.key});
      expect(profile.roleLabel, entry.value);
      expect(UserProfile.fromJson(profile.toJson()), profile);
      expect(profile.copyWith(name: 'Новое имя').role, entry.key);
    }
  });

  test('parses profile data and resolves a relative avatar URL', () {
    final profile = UserProfile.fromJson(<String, dynamic>{
      'id': 'user-1',
      'name': 'Айгерим Бектурова',
      'email': 'aigerim@jospar.me',
      'avatarUrl': '/uploads/avatars/user-1.jpg',
    });

    expect(profile.id, 'user-1');
    expect(profile.name, 'Айгерим Бектурова');
    expect(profile.email, 'aigerim@jospar.me');
    expect(profile.avatarUrl, 'https://jospar.me/uploads/avatars/user-1.jpg');
  });

  test('keeps avatar empty when the API has no photo', () {
    final profile = UserProfile.fromJson(<String, dynamic>{
      'id': 'user-2',
      'name': 'Пользователь',
      'email': 'user@jospar.me',
      'avatarUrl': null,
    });

    expect(profile.avatarUrl, isNull);
  });
}
