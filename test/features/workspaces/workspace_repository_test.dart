import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/workspaces/data/repositories/workspace_repository_impl.dart';
import 'package:jospar/features/workspaces/domain/entities/create_workspace_request.dart';
import 'package:jospar/features/workspaces/domain/entities/workspace_model.dart';

void main() {
  late Dio dio;
  late WorkspaceRepositoryImpl repository;
  late List<RequestOptions> sent;
  dynamic response;
  setUp(() {
    dio = Dio();
    repository = WorkspaceRepositoryImpl(dio);
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
  for (final archived in [false, true]) {
    for (final wrapper in <String?>[null, 'data', 'workspaces', 'items']) {
      test(
        'GET archived=$archived wrapper=$wrapper preserves headers and filtering',
        () async {
          final rows = [
            {'id': 123, 'name': 'Name'},
            {'name': 'No id'},
            null,
            'invalid',
          ];
          response = wrapper == null ? rows : {wrapper: rows};
          final result = await (archived
              ? repository.getArchivedWorkspaces()
              : repository.getWorkspaces());
          expect(result, [const WorkspaceModel(id: '123', name: 'Name')]);
          expect(sent.single.method, 'GET');
          expect(
            sent.single.path,
            archived ? 'workspaces/archived' : 'workspaces',
          );
          expect(sent.single.headers['Cache-Control'], 'no-cache');
        },
      );
    }
  }
  for (final wrapper in <String?>[null, 'data', 'workspace']) {
    for (final color in <String?>[null, '', '#123456']) {
      test(
        'POST wrapper=$wrapper color=$color preserves body and response fallback',
        () async {
          final payload = {'id': 'created', 'name': ' ', 'color': ''};
          response = wrapper == null ? payload : {wrapper: payload};
          final result = await repository.createWorkspace(
            CreateWorkspaceRequest(name: 'Name', color: color),
          );
          expect(sent.single.method, 'POST');
          expect(sent.single.path, 'workspaces');
          expect(sent.single.data, {'name': 'Name', 'color': ?color});
          // Existing copyWith(null) retains the parsed empty color.
          expect(
            result,
            WorkspaceModel(id: 'created', name: 'Name', color: color ?? ''),
          );
        },
      );
    }
  }
  test('POST preserves populated server fields', () async {
    response = {'id': 123, 'name': 'Server', 'color': '#abcdef'};
    expect(
      await repository.createWorkspace(
        const CreateWorkspaceRequest(name: 'Client', color: '#123456'),
      ),
      const WorkspaceModel(id: '123', name: 'Server', color: '#abcdef'),
    );
  });
  test('POST rejects missing created id', () async {
    response = {'name': 'Name'};
    await expectLater(
      repository.createWorkspace(const CreateWorkspaceRequest(name: 'Name')),
      throwsA(isA<WorkspaceException>()),
    );
  });
  test('GET rejects invalid list response', () async {
    response = 'invalid';
    await expectLater(
      repository.getWorkspaces(),
      throwsA(isA<WorkspaceException>()),
    );
  });
}
