import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/projects/data/models/create_project_request.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';
import 'package:jospar/features/projects/domain/repositories/project_repository.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_cubit.dart';

void main() {
  const workspaceOne = 'w1';

  test('filters projects by workspace and sorts pinned first stably', () async {
    final repository = _FakeProjectRepository(
      projects: <ProjectModel>[
        _project(id: '1', workspaceId: workspaceOne),
        _project(id: '2', workspaceId: 'w2', isPinned: true),
        _project(id: '3', workspaceId: workspaceOne, isPinned: true),
        _project(id: '4', workspaceId: workspaceOne),
        _project(id: '5', workspaceId: '', isPinned: true),
      ],
    );
    final cubit = ProjectsCubit(repository);

    await cubit.loadForWorkspace(workspaceOne);

    expect(cubit.state.projects.map((item) => item.id), <String>[
      '3',
      '1',
      '4',
    ]);
    await cubit.close();
  });

  test('rejects invalid dates without calling repository', () async {
    final repository = _FakeProjectRepository();
    final cubit = ProjectsCubit(repository);

    final success = await cubit.createProject(
      _request(start: DateTime(2026, 9, 2), end: DateTime(2026, 9, 1)),
    );

    expect(success, isFalse);
    expect(repository.createCalls, 0);
    expect(cubit.state.creationError, contains('раньше'));
    await cubit.close();
  });

  test(
    'prevents duplicate submission and adds created project immediately',
    () async {
      final completer = Completer<ProjectModel>();
      final repository = _FakeProjectRepository(createCompleter: completer);
      final cubit = ProjectsCubit(repository);
      await cubit.loadForWorkspace(workspaceOne);
      final request = _request();

      final first = cubit.createProject(request);
      final duplicate = await cubit.createProject(request);
      expect(duplicate, isFalse);
      expect(repository.createCalls, 1);

      completer.complete(
        _project(id: 'created', workspaceId: workspaceOne, isPinned: true),
      );
      expect(await first, isTrue);
      expect(cubit.state.projects.single.id, 'created');
      expect(cubit.state.creationRevision, 1);
      await cubit.close();
    },
  );

  test('finishes creating when project targets another workspace', () async {
    final repository = _FakeProjectRepository();
    final cubit = ProjectsCubit(repository);
    await cubit.loadForWorkspace(workspaceOne);

    final success = await cubit.createProject(
      _request().copyWith(workspaceId: 'w2'),
    );

    expect(success, isTrue);
    expect(cubit.state.isCreating, isFalse);
    expect(cubit.state.workspaceId, workspaceOne);
    expect(cubit.state.projects, isEmpty);
    await cubit.close();
  });
}

ProjectModel _project({
  required String id,
  required String workspaceId,
  bool isPinned = false,
}) {
  return ProjectModel(
    id: id,
    code: 'P$id',
    name: 'Проект $id',
    workspaceId: workspaceId,
    start: DateTime(2026, 8, 21),
    end: DateTime(2026, 9, 21),
    isPinned: isPinned,
  );
}

CreateProjectRequest _request({DateTime? start, DateTime? end}) {
  return CreateProjectRequest(
    code: 'APP',
    name: 'Приложение',
    workspaceId: 'w1',
    start: start ?? DateTime(2026, 8, 21),
    end: end ?? DateTime(2026, 9, 21),
  );
}

class _FakeProjectRepository implements ProjectRepository {
  _FakeProjectRepository({
    this.projects = const <ProjectModel>[],
    this.createCompleter,
  });

  final List<ProjectModel> projects;
  final Completer<ProjectModel>? createCompleter;
  int createCalls = 0;

  @override
  Future<ProjectModel> createProject(CreateProjectRequest request) {
    createCalls++;
    return createCompleter?.future ??
        Future<ProjectModel>.value(
          _project(id: 'created', workspaceId: request.workspaceId),
        );
  }

  @override
  Future<List<ProjectModel>> getProjects() async => projects;
}
