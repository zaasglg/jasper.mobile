import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/network/api_constants.dart';
import 'package:jospar/core/widgets/user_avatar.dart';
import 'package:jospar/features/collaboration/data/models/managed_space_dto.dart';
import 'package:jospar/features/collaboration/data/models/space_member_dto.dart';
import 'package:jospar/features/collaboration/data/models/space_member_project_dto.dart';
import 'package:jospar/features/collaboration/data/models/space_kind_path.dart';
import 'package:jospar/features/collaboration/domain/entities/managed_space.dart';
import 'package:jospar/features/collaboration/domain/entities/space_member.dart';
import 'package:jospar/features/collaboration/domain/entities/space_member_project.dart';
import 'package:jospar/features/collaboration/domain/entities/space_kind.dart';
import 'package:jospar/features/collaboration/presentation/workspace_participants_panel.dart';

void main() {
  test(
    'managed space maps typed fields and retains unknown data only in DTO',
    () {
      final json = <String, dynamic>{
        'id': 123,
        'name': 'Name',
        'workspaceId': 'w',
        'code': 'PR',
        'description': 'Description',
        'color': '#123456',
        'logoUrl': '/logo',
        'isPinned': true,
        'unknown': {'retained': true},
      };
      final dto = ManagedSpaceDto.fromJson(json);
      const entity = ManagedSpace(
        id: '123',
        name: 'Name',
        workspaceId: 'w',
        code: 'PR',
        description: 'Description',
        color: '#123456',
        logoUrl: '/logo',
        isPinned: true,
      );
      expect(dto.toEntity(), entity);
      expect(dto.toJson(), {...json, 'id': '123'});
      expect(ManagedSpaceDto.fromJson(dto.toJson()).toJson(), dto.toJson());
      expect(ManagedSpaceDto.fromEntity(entity).toEntity(), entity);
      expect(
        ManagedSpaceDto.fromEntity(entity).toJson().containsKey('unknown'),
        isFalse,
      );
      expect(entity.copyWith(name: 'Other').code, 'PR');
      expect(dto.copyWith(name: 'Other').id, '123');
    },
  );
  test('managed missing/null/non-string fields keep coercion rules', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {'id': null, 'name': null},
    ]) {
      expect(
        ManagedSpaceDto.fromJson(json).toEntity(),
        const ManagedSpace(id: '', name: ''),
      );
    }
    final entity = ManagedSpaceDto.fromJson({
      'id': 123,
      'name': {'nested': true},
      'code': [1],
      'isPinned': 'true',
    }).toEntity();
    expect(entity.id, '123');
    expect(entity.name, '{nested: true}');
    expect(entity.code, '[1]');
    expect(entity.isPinned, isFalse);
  });
  test(
    'members preserve nested-user priorities, defaults and typed fields',
    () {
      final dto = SpaceMemberDto.fromJson({
        'userId': 'member',
        'role': 'ADMIN',
        'access': 'GUEST',
        'isWorkspaceOwner': true,
        'isGuest': true,
        'projectCount': 3.0,
        'lastActiveAt': 'Вчера в 12:00',
        'projects': [
          {'name': 'Name'},
          {'title': 'Title'},
          {},
          'Scalar',
          null,
        ],
        'user': {
          'id': 'nested',
          'email': 'mail',
          'about': 'About',
          'projectCount': 9,
        },
      });
      final entity = dto.toEntity();
      expect(entity.userId, 'member');
      expect(entity.name, 'mail');
      expect(entity.email, 'mail');
      expect(entity.role, 'ADMIN');
      expect(entity.access, 'GUEST');
      expect(entity.about, 'About');
      expect(entity.isWorkspaceOwner, isTrue);
      expect(entity.isGuest, isTrue);
      expect(entity.projectCount, 3);
      expect(entity.lastActiveAt, 'Вчера в 12:00');
      expect(entity.projects.map((p) => p.name), [
        'Name',
        'Title',
        'Проект',
        'Scalar',
        'null',
      ]);
      expect(SpaceMemberDto.fromJson(dto.toJson()), dto);
      expect(SpaceMemberDto.fromEntity(entity).toEntity(), entity);
      expect(entity.copyWith(role: 'EXECUTOR').projects, entity.projects);
      expect(dto.copyWith(role: 'EXECUTOR').about, 'About');
    },
  );
  test(
    'members missing/null/non-string values retain explicit defaults/coercion',
    () {
      for (final json in <Map<String, dynamic>>[
        {},
        {'userId': null, 'role': null, 'user': null, 'projects': null},
      ]) {
        expect(
          SpaceMemberDto.fromJson(json).toEntity(),
          const SpaceMember(userId: '', name: ''),
        );
      }
      final member = SpaceMemberDto.fromJson({
        'id': 123,
        'name': {'x': 1},
        'email': ['a'],
        'role': false,
        'isWorkspaceOwner': 'true',
        'projectCount': '3',
        'lastActiveAt': 42,
        'projects': 'invalid',
      }).toEntity();
      expect(member.userId, '123');
      expect(member.name, '{x: 1}');
      expect(member.email, '[a]');
      expect(member.role, 'false');
      expect(member.isWorkspaceOwner, isFalse);
      expect(member.projectCount, isNull);
      expect(member.lastActiveAt, '42');
      expect(member.projects, isEmpty);
      expect(
        () => SpaceMemberDto.fromJson({'avatarUrl': 123}),
        throwsA(isA<TypeError>()),
      );
    },
  );
  test('null and empty project lists map to the same entity', () {
    expect(
      SpaceMemberDto.fromJson({'projects': null}).toEntity(),
      SpaceMemberDto.fromJson({'projects': []}).toEntity(),
    );
  });
  test('nested field fallback preserves root null precedence behavior', () {
    final entity = SpaceMemberDto.fromJson({
      'projectCount': null,
      'user': {
        'projectCount': 3.0,
        'isGuest': true,
        'lastActiveAt': '2026-01-01T12:00:00Z',
      },
    }).toEntity();
    expect(entity.projectCount, 3);
    expect(entity.isGuest, isTrue);
    expect(entity.lastActiveAt, '2026-01-01T12:00:00Z');
  });
  for (final avatar in [
    'https://cdn/x.png',
    '/avatar.png',
    'data:image/png;base64,...',
  ]) {
    test('avatar DTO → entity → UI resolver is stable: $avatar', () {
      final entity = SpaceMemberDto.fromJson({'avatarUrl': avatar}).toEntity();
      final expected = avatar.startsWith('/')
          ? ApiConstants.origin.resolve(avatar).toString()
          : avatar;
      expect(entity.avatarUrl, expected);
      expect(resolveUserAvatarUrl(entity.avatarUrl), expected);
      expect(SpaceMemberDto.fromEntity(entity).toEntity(), entity);
    });
  }
  test('direct entity constructors do not normalize URLs', () {
    expect(
      const SpaceMember(userId: '', name: '', avatarUrl: '/raw').avatarUrl,
      '/raw',
    );
  });
  test('project DTO conversion, fallback and copy preserve domain name', () {
    const entity = SpaceMemberProject(name: 'Name');
    final dto = SpaceMemberProjectDto.fromEntity(entity);
    expect(dto.toEntity(), entity);
    expect(SpaceMemberProjectDto.fromJson(dto.toJson()), dto);
    expect(dto.copyWith(name: 'Other').name, 'Other');
    expect(entity.copyWith(name: 'Other').name, 'Other');
    expect(
      SpaceMemberProjectDto.fromJson({'name': null, 'title': 123}).name,
      '123',
    );
  });
  test('space kinds preserve API paths and user labels', () {
    expect(SpaceKind.values, [SpaceKind.project, SpaceKind.workspace]);
    expect(SpaceKind.project.path, 'projects');
    expect(SpaceKind.workspace.path, 'workspaces');
    expect(SpaceKind.project.label, 'Проект');
    expect(SpaceKind.workspace.label, 'Workspace');
  });
  testWidgets(
    'fractional projectCount intentionally truncates before guest grouping',
    (tester) async {
      final member = SpaceMemberDto.fromJson({
        'name': 'Guest',
        'access': 'GUEST',
        'projectCount': 1.9,
      }).toEntity();
      expect(member.projectCount, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkspaceParticipantsPanel(
              members: [member],
              actions: (_) => null,
            ),
          ),
        ),
      );
      expect(find.text('Гости одной доски · 1'), findsOneWidget);
      expect(find.text('Гости нескольких досок · 0'), findsOneWidget);
    },
  );
}
