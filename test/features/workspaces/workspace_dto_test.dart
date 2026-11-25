import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/network/api_constants.dart';
import 'package:jospar/features/workspaces/data/models/workspace_dto.dart';
import 'package:jospar/features/workspaces/data/models/create_workspace_request_dto.dart';
import 'package:jospar/features/workspaces/domain/entities/workspace_model.dart';
import 'package:jospar/features/workspaces/domain/entities/create_workspace_request.dart';
import 'package:jospar/features/tasks/data/models/task_creation_models.dart';

void main() {
  test('parses direct and nested logos with API origin', () {
    final direct = WorkspaceDto.fromJson({
      'id': 'one',
      'name': 'Name',
      'logoUrl': '/uploads/one.png',
    });
    final nested = WorkspaceDto.fromJson({
      'logo': {'url': 'https://cdn.example/two.png'},
    });
    expect(
      direct.logoUrl,
      ApiConstants.origin.resolve('/uploads/one.png').toString(),
    );
    expect(nested.logoUrl, 'https://cdn.example/two.png');
    expect(WorkspaceDto.fromJson(direct.toJson()), direct);
  });
  test('preserves embedded base64 logo', () {
    const logo = 'data:image/jpeg;base64,AQID';
    expect(WorkspaceDto.fromJson({'logoUrl': logo}).logoUrl, logo);
  });
  test('missing and null fields preserve defaults', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {'id': null, 'name': null, 'color': null, 'logoUrl': null},
    ]) {
      expect(WorkspaceDto.fromJson(json).toJson(), {
        'id': '',
        'name': '',
        'color': null,
        'logoUrl': null,
      });
      expect(CreateWorkspaceRequestDto.fromJson(json).toJson(), {'name': ''});
    }
  });
  test('non-string id/name/color intentionally use toString', () {
    final dto = WorkspaceDto.fromJson({
      'id': 123,
      'name': {'nested': 'value'},
      'color': [1, 2],
    });
    expect(dto.id, '123');
    expect(dto.name, '{nested: value}');
    expect(dto.color, '[1, 2]');
    final request = CreateWorkspaceRequestDto.fromJson({
      'name': {'nested': 'value'},
      'color': 123,
    });
    expect(request.toJson(), {'name': '{nested: value}', 'color': '123'});
  });
  test('logo aliases, nesting and branding preserve parsing rules', () {
    final expected = ApiConstants.origin.resolve('/a.png').toString();
    for (final key in ['logoUrl', 'logo_url', 'logo', 'imageUrl']) {
      expect(WorkspaceDto.fromJson({key: ' /a.png '}).logoUrl, expected);
      for (final nested in ['url', 'src', 'path']) {
        expect(
          WorkspaceDto.fromJson({
            key: {nested: '/a.png'},
          }).logoUrl,
          expected,
        );
      }
    }
    for (final key in ['logoUrl', 'logo_url']) {
      expect(
        WorkspaceDto.fromJson({
          'branding': {key: '/a.png'},
        }).logoUrl,
        expected,
      );
    }
    expect(
      WorkspaceDto.fromJson({'logoUrl': '', 'logo': '/a.png'}).logoUrl,
      isNull,
    );
    expect(
      WorkspaceDto.fromJson({
        'logoUrl': 123,
        'branding': {'logoUrl': '/a.png'},
      }).logoUrl,
      expected,
    );
    for (final invalid in <Object>[123, [], {}, '  ']) {
      expect(WorkspaceDto.fromJson({'logoUrl': invalid}).logoUrl, isNull);
    }
  });
  test('workspace conversions preserve every field without normalization', () {
    const entity = WorkspaceModel(
      id: 'w',
      name: 'Name',
      color: '',
      logoUrl: '/raw.png',
    );
    final dto = WorkspaceDto.fromEntity(entity);
    expect(dto.toJson(), {
      'id': 'w',
      'name': 'Name',
      'color': '',
      'logoUrl': '/raw.png',
    });
    expect(dto.toEntity(), entity);
    expect(WorkspaceDto.fromEntity(dto.toEntity()), dto);
    expect(entity.copyWith(name: 'Other').logoUrl, '/raw.png');
    expect(dto.copyWith(name: 'Other').color, '');
  });
  test(
    'create request body and conversions preserve nullable color contract',
    () {
      for (final color in <String?>[null, '', '#E45D70']) {
        final entity = CreateWorkspaceRequest(name: 'Маркетинг', color: color);
        final dto = CreateWorkspaceRequestDto.fromEntity(entity);
        expect(dto.toJson(), {'name': 'Маркетинг', 'color': ?color});
        expect(CreateWorkspaceRequestDto.fromJson(dto.toJson()), dto);
        expect(dto.toEntity(), entity);
        expect(entity.copyWith(name: 'Other').color, color);
        expect(dto.copyWith(name: 'Other').color, color);
      }
    },
  );
  test('catalog maps only nested workspaces and preserves user payload', () {
    final json = <String, dynamic>{
      'workspaces': [
        {'id': 123, 'name': 'Name', 'logo': '/a.png'},
      ],
      'user': {
        'id': 'u',
        'name': 'User',
        'email': 'mail',
        'avatarUrl': null,
        'role': 'ADMIN',
      },
    };
    final catalog = TaskCreationCatalog.fromJson(json);
    expect(
      catalog.workspaces.single,
      WorkspaceModel(
        id: '123',
        name: 'Name',
        logoUrl: ApiConstants.origin.resolve('/a.png').toString(),
      ),
    );
    expect(catalog.toJson()['workspaces'], [
      WorkspaceDto.fromEntity(catalog.workspaces.single).toJson(),
    ]);
    expect(catalog.toJson()['user'], {...json['user'] as Map, 'locale': 'ru'});
    expect(TaskCreationCatalog.fromJson(catalog.toJson()), catalog);
  });
}
