import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/network/api_constants.dart';
import 'package:jospar/features/profile/data/models/user_profile_dto.dart';
import 'package:jospar/features/profile/domain/entities/user_profile.dart';
import 'package:jospar/features/tasks/data/models/task_creation_models.dart';

void main() {
  test(
    'parses profile, resolves relative avatar and serializes all fields',
    () {
      final dto = UserProfileDto.fromJson({
        'id': 'user-1',
        'name': 'Айгерим',
        'email': 'a@jospar.me',
        'role': 'ADMIN',
        'avatarUrl': ' /uploads/avatar.jpg ',
      });
      expect(dto.toJson(), {
        'id': 'user-1',
        'name': 'Айгерим',
        'email': 'a@jospar.me',
        'role': 'ADMIN',
        'avatarUrl': ApiConstants.origin
            .resolve('/uploads/avatar.jpg')
            .toString(),
      });
      expect(UserProfileDto.fromJson(dto.toJson()), dto);
      expect(dto.copyWith(name: 'Новое имя').role, 'ADMIN');
    },
  );

  for (final json in <Map<String, dynamic>>[
    {},
    {'id': null, 'name': null, 'email': null, 'role': null, 'avatarUrl': null},
  ]) {
    test('missing/null fields keep existing defaults: $json', () {
      final dto = UserProfileDto.fromJson(json);
      expect(dto.toJson(), {
        'id': '',
        'name': '',
        'email': '',
        'role': '',
        'avatarUrl': null,
      });
    });
  }

  test(
    'non-string scalar and nested object values retain toString behavior',
    () {
      final dto = UserProfileDto.fromJson({
        'id': 123,
        'name': {'nested': 'value'},
        'email': ['a', 'b'],
        'role': true,
        'avatarUrl': {'url': '/photo.jpg'},
      });
      expect(dto.id, '123');
      expect(dto.name, '{nested: value}');
      expect(dto.email, '[a, b]');
      expect(dto.role, 'true');
      expect(dto.avatarUrl, isNull);
    },
  );

  for (final key in ['avatarUrl', 'avatar_url', 'avatar']) {
    test('supports avatar alias $key and preserves absolute URLs', () {
      final dto = UserProfileDto.fromJson({
        key: 'https://cdn.example/photo.jpg',
      });
      expect(dto.avatarUrl, 'https://cdn.example/photo.jpg');
    });
  }
  test(
    'avatar aliases use null fallback, with no fallback for invalid non-null values',
    () {
      expect(
        UserProfileDto.fromJson({
          'avatarUrl': null,
          'avatar_url': '/a.jpg',
        }).avatarUrl,
        ApiConstants.origin.resolve('/a.jpg').toString(),
      );
      for (final invalid in <Object>['', '  ', 123, [], {}]) {
        expect(
          UserProfileDto.fromJson({
            'avatarUrl': invalid,
            'avatar': '/a.jpg',
          }).avatarUrl,
          isNull,
        );
      }
    },
  );

  const entity = UserProfile(
    id: '1',
    name: 'Name',
    email: 'mail',
    avatarUrl: '/raw.jpg',
    role: 'OWNER',
  );
  test('fromEntity preserves every field without normalizing', () {
    final dto = UserProfileDto.fromEntity(entity);
    expect(dto.toJson(), {
      'id': '1',
      'name': 'Name',
      'email': 'mail',
      'avatarUrl': '/raw.jpg',
      'role': 'OWNER',
    });
  });
  test('toEntity preserves every field and equality', () {
    const dto = UserProfileDto(
      id: '1',
      name: 'Name',
      email: 'mail',
      avatarUrl: '/raw.jpg',
      role: 'OWNER',
    );
    expect(dto.toEntity(), entity);
    expect(UserProfileDto.fromEntity(dto.toEntity()), dto);
  });
  test('null avatar survives entity round trip', () {
    const profile = UserProfile(id: '', name: '', email: '');
    expect(UserProfileDto.fromEntity(profile).toEntity(), profile);
    expect(
      UserProfileDto.fromEntity(profile).toJson().containsKey('avatarUrl'),
      isTrue,
    );
    expect(UserProfileDto.fromEntity(profile).toJson()['avatarUrl'], isNull);
  });

  test(
    'task creation catalog maps nested user through DTO in both directions',
    () {
      final catalog = TaskCreationCatalog.fromJson({
        'workspaces': [],
        'user': {
          'id': 123,
          'name': 'Name',
          'email': 'mail',
          'role': 'ADMIN',
          'avatar': '/a.jpg',
        },
      });
      expect(
        catalog.user,
        UserProfile(
          id: '123',
          name: 'Name',
          email: 'mail',
          role: 'ADMIN',
          avatarUrl: ApiConstants.origin.resolve('/a.jpg').toString(),
        ),
      );
      expect(
        catalog.toJson()['user'],
        UserProfileDto.fromEntity(catalog.user).toJson(),
      );
      expect(TaskCreationCatalog.fromJson(catalog.toJson()), catalog);
      final noAvatar = catalog.copyWith(
        user: const UserProfile(id: '', name: '', email: ''),
      );
      expect((noAvatar.toJson()['user'] as Map)['avatarUrl'], isNull);
    },
  );
}
