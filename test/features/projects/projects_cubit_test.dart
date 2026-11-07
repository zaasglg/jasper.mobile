import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/projects/data/models/create_project_request.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/projects/data/repositories/project_repository_impl.dart';
import 'package:jospar/features/projects/domain/repositories/project_repository.dart';
import 'package:jospar/features/projects/domain/repositories/project_task_repository.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_cubit.dart';

void main() {
  const workspaceOne = 'w1';

  test('late refresh cannot remove a successfully created project', () async {
    final repository = _FakeProjectRepository();
    final cubit = ProjectsCubit(repository);
    addTearDown(cubit.close);
    await cubit.loadForWorkspace(workspaceOne);
    final old = Completer<List<ProjectModel>>();
    repository.nextLoad = old;
    final refreshing = cubit.loadForWorkspace(workspaceOne, refresh: true);
    expect(await cubit.createProject(_request()), isTrue);
    old.complete([]);
    await refreshing;
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.projects.map((item) => item.id), ['created']);
    expect(cubit.state.creationRevision, 1);
    expect(cubit.state.isLoading, isFalse);
  });

  test('refresh while creating cannot unlock duplicate submission', () async {
    final pending = Completer<ProjectModel>();
    final repository = _FakeProjectRepository(createCompleter: pending);
    final cubit = ProjectsCubit(repository);
    addTearDown(cubit.close);
    await cubit.loadForWorkspace(workspaceOne);
    final creating = cubit.createProject(_request());
    await cubit.loadForWorkspace(workspaceOne, refresh: true);
    final duplicate = cubit.createProject(_request());
    pending.complete(_project(id: 'created', workspaceId: workspaceOne));
    expect(await creating, isTrue);
    expect(await duplicate, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(repository.createCalls, 1);
    expect(cubit.state.projects.map((item) => item.id), ['created']);
    expect(cubit.state.isCreating, isFalse);
  });

  test(
    'old workspace creation failure does not leak into new workspace',
    () async {
      final pending = Completer<ProjectModel>();
      final repository = _FakeProjectRepository(createCompleter: pending);
      final cubit = ProjectsCubit(repository);
      addTearDown(cubit.close);
      await cubit.loadForWorkspace(workspaceOne);
      final creating = cubit.createProject(_request());
      await cubit.loadForWorkspace('w2');
      pending.completeError(
        const ProjectException('Нет доступа к первому workspace'),
      );
      expect(await creating, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.workspaceId, 'w2');
      expect(cubit.state.creationError, isNull);
      expect(cubit.state.isCreating, isFalse);
      expect(cubit.state.isLoading, isFalse);
    },
  );

  test(
    'successful creation stays successful if the queued refresh fails',
    () async {
      final pending = Completer<ProjectModel>();
      final reading = Completer<List<ProjectModel>>();
      final repository = _FakeProjectRepository(createCompleter: pending);
      final cubit = ProjectsCubit(repository);
      addTearDown(cubit.close);
      await cubit.loadForWorkspace(workspaceOne);
      final creating = cubit.createProject(_request());
      repository.nextLoad = reading;
      await cubit.loadForWorkspace(workspaceOne, refresh: true);
      pending.complete(_project(id: 'created', workspaceId: workspaceOne));
      expect(await creating.timeout(const Duration(seconds: 5)), isTrue);
      reading.completeError(const ProjectException('Ошибка обновления'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.projects.map((item) => item.id), ['created']);
      expect(cubit.state.creationRevision, 1);
      expect(cubit.state.isCreating, isFalse);
      expect(cubit.state.errorMessage, 'Ошибка обновления');
    },
  );

  test('only the latest workspace is loaded after creation finishes', () async {
    final pending = Completer<ProjectModel>();
    final repository = _FakeProjectRepository(
      createCompleter: pending,
      projects: [
        _project(id: 'second', workspaceId: 'w2'),
        _project(id: 'third', workspaceId: 'w3'),
      ],
    );
    final cubit = ProjectsCubit(repository);
    addTearDown(cubit.close);
    await cubit.loadForWorkspace(workspaceOne);
    final creating = cubit.createProject(_request());
    await cubit.loadForWorkspace('w2');
    await cubit.loadForWorkspace('w3');
    pending.complete(_project(id: 'created', workspaceId: workspaceOne));
    expect(await creating, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.workspaceId, 'w3');
    expect(cubit.state.projects.map((item) => item.id), ['third']);
    expect(cubit.state.isCreating, isFalse);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.creationRevision, 1);
  });

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
    expect(cubit.state.selectedProjectId, '3');
    await cubit.close();
  });

  test('selects a project and restores it for the workspace', () async {
    final repository = _FakeProjectRepository(
      projects: <ProjectModel>[
        _project(id: '1', workspaceId: workspaceOne),
        _project(id: '2', workspaceId: workspaceOne),
      ],
    );
    final cubit = ProjectsCubit(repository);

    await cubit.loadForWorkspace(workspaceOne);
    cubit.selectProject('2');

    expect(cubit.state.selectedProjectId, '2');

    await cubit.loadForWorkspace(workspaceOne);
    expect(cubit.state.selectedProjectId, '2');
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
      expect(cubit.state.selectedProjectId, 'created');
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

  test('calculates root progress from its own and child tasks', () async {
    final child = _project(id: 'child', workspaceId: workspaceOne);
    final root = _project(
      id: 'root',
      workspaceId: workspaceOne,
      children: <ProjectModel>[child],
    );
    final taskRepository = _FakeProjectTaskRepository(<ProjectTaskModel>[
      const ProjectTaskModel(
        id: 'done-by-status',
        projectId: 'root',
        status: 'DONE',
      ),
      const ProjectTaskModel(
        id: 'done-by-progress',
        projectId: 'child',
        status: 'IN_PROGRESS',
        progress: 100,
      ),
      const ProjectTaskModel(
        id: 'open',
        projectId: 'child',
        status: 'IN_PROGRESS',
        progress: 40,
      ),
    ]);
    final cubit = ProjectsCubit(
      _FakeProjectRepository(projects: <ProjectModel>[root]),
      taskRepository: taskRepository,
    );

    await cubit.loadForWorkspace(workspaceOne);

    expect(taskRepository.requestedIds, containsAll(<String>['root', 'child']));
    expect(cubit.state.projectTaskProgress['root'], 67);
    expect(cubit.state.projectTaskSummaries['root']?.completed, 2);
    expect(cubit.state.projectTaskSummaries['root']?.total, 3);
    expect(cubit.state.isProgressLoading, isFalse);
    await cubit.close();
  });
}

ProjectModel _project({
  required String id,
  required String workspaceId,
  bool isPinned = false,
  List<ProjectModel> children = const <ProjectModel>[],
}) {
  return ProjectModel(
    id: id,
    code: 'P$id',
    name: 'Проект $id',
    workspaceId: workspaceId,
    start: DateTime(2026, 8, 21),
    end: DateTime(2026, 9, 21),
    isPinned: isPinned,
    children: children,
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

  List<ProjectModel> projects;
  Completer<List<ProjectModel>>? nextLoad;
  final Completer<ProjectModel>? createCompleter;
  int createCalls = 0;

  @override
  Future<ProjectModel> createProject(CreateProjectRequest request) async {
    createCalls++;
    final created =
        await (createCompleter?.future ??
            Future.value(
              _project(id: 'created', workspaceId: request.workspaceId),
            ));
    projects = [
      ...projects.where((project) => project.id != created.id),
      created,
    ];
    return created;
  }

  @override
  Future<List<ProjectModel>> getProjects() async {
    final pending = nextLoad;
    nextLoad = null;
    return pending?.future ?? List.of(projects);
  }
}

class _FakeProjectTaskRepository implements ProjectTaskRepository {
  _FakeProjectTaskRepository(this.tasks);

  final List<ProjectTaskModel> tasks;
  List<String> requestedIds = const <String>[];

  @override
  Future<List<ProjectTaskModel>> getTasksForProjectIds(
    List<String> projectIds,
  ) async {
    requestedIds = projectIds;
    return tasks;
  }
}
