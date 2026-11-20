import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/collaboration/data/collaboration_repository_impl.dart';
import 'package:jospar/features/collaboration/domain/entities/managed_space.dart';
import 'package:jospar/features/collaboration/domain/entities/space_kind.dart';

void main() {
  late Dio dio;
  late CollaborationRepositoryImpl repository;
  late List<RequestOptions> sent;
  dynamic response;
  setUp(() {
    dio = Dio();
    repository = CollaborationRepositoryImpl(dio);
    sent = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          sent.add(request);
          handler.resolve(
            Response(requestOptions: request, statusCode: 200, data: response),
          );
        },
      ),
    );
  });
  tearDown(() => dio.close());
  for (final kind in SpaceKind.values) {
    final prefix = kind == SpaceKind.project ? 'projects' : 'workspaces';
    for (final wrapper in <String?>[null, 'data', 'project', 'workspace']) {
      test('getSpace $kind wrapper=$wrapper maps typed fields', () async {
        final object = {
          'id': 'a/b',
          'name': 'Name',
          'workspaceId': 'w',
          'unknown': 42,
        };
        response = wrapper == null ? object : {wrapper: object};
        expect(
          await repository.getSpace(kind, 'a/b'),
          const ManagedSpace(id: 'a/b', name: 'Name', workspaceId: 'w'),
        );
        expect(sent.single.method, 'GET');
        expect(sent.single.path, '$prefix/a%2Fb');
      });
    }
    test(
      'mutations preserve endpoint encoding and request bodies: $kind',
      () async {
        response = {};
        await repository.updateSpace(kind, 'a/b', {
          'name': 'New',
          'logoUrl': null,
        });
        expect(sent.last.method, 'PATCH');
        expect(sent.last.path, '$prefix/a%2Fb');
        expect(sent.last.data, {'name': 'New', 'logoUrl': null});
        await repository.archive(kind, 'a/b');
        expect(sent.last.path, '$prefix/a%2Fb/archive');
        expect(sent.last.method, 'PATCH');
        await repository.restore(kind, 'a/b');
        expect(sent.last.path, '$prefix/a%2Fb/restore');
        await repository.delete(kind, 'a/b');
        expect(sent.last.method, 'DELETE');
        expect(sent.last.path, '$prefix/a%2Fb');
        await repository.removeMember(kind, 'a/b', 'u/v');
        expect(sent.last.path, '$prefix/a%2Fb/members/u%2Fv');
        await repository.addMember(kind, 'a/b', 'u/v', 'ADMIN');
        if (kind == SpaceKind.project) {
          expect(sent.last.method, 'POST');
          expect(sent.last.data, {'email': 'u/v', 'role': 'ADMIN'});
        } else {
          expect(sent[sent.length - 2].method, 'POST');
          expect(sent[sent.length - 2].data, {'userId': 'u/v'});
          expect(sent.last.path, '$prefix/a%2Fb/members/u%2Fv/role');
          expect(sent.last.data, {'role': 'ADMIN'});
        }
      },
    );
    test('archive wrapper and workspace query preserved: $kind', () async {
      response = {
        'data': {
          'items': [
            {'id': '1', 'name': 'Name'},
            false,
          ],
        },
      };
      expect(
        (await repository.archived(kind, workspaceId: 'w')).single.id,
        '1',
      );
      expect(sent.single.path, '$prefix/archived');
      expect(
        sent.single.queryParameters,
        kind == SpaceKind.project ? {'workspaceId': 'w'} : {},
      );
    });
  }
  test('workspace guests deduplicate and invitations retain access', () async {
    response = {
      'members': [
        {'id': 'u', 'name': 'Member'},
      ],
      'guests': [
        {'id': 'u'},
        {'id': 'g', 'projectCount': 3.0},
      ],
      'pendingInvites': [
        {'id': 'invite', 'email': 'mail'},
      ],
    };
    final members = await repository.members(SpaceKind.workspace, 'w');
    expect(members.map((m) => m.userId), ['u', 'g', 'invite']);
    expect(members[1].access, 'GUEST');
    expect(members[1].projectCount, 3);
    expect(members[2].access, 'INVITATION');
  });
  for (final workspaceId in ['', 'a/b']) {
    test(
      'candidate endpoint and nested user conversion: $workspaceId',
      () async {
        response = {
          'data': {
            'users': [
              {
                'userId': 'u',
                'user': {'name': 'Name'},
              },
            ],
          },
        };
        expect((await repository.candidates(workspaceId)).single.name, 'Name');
        expect(
          sent.single.path,
          workspaceId.isEmpty ? 'users' : 'workspaces/a%2Fb/members',
        );
      },
    );
  }
}
