import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/profile/data/models/user_profile.dart';

void main() {
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
