import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/tasks/data/models/kanban_column_model.dart';
import 'package:jospar/features/tasks/data/repositories/my_tasks_repository_impl.dart';
import 'package:jospar/features/tasks/domain/entities/task_extra_field.dart';
import 'package:jospar/features/tasks/domain/repositories/my_task_fields_storage.dart';
import 'package:jospar/features/tasks/domain/repositories/my_tasks_repository.dart';
import 'package:jospar/features/tasks/presentation/cubit/my_tasks_cubit.dart';
import 'package:jospar/features/tasks/presentation/cubit/my_tasks_state.dart';

void main() {
  const child = ProjectModel(
    id: 'child',
    code: 'CH',
    name: 'Child',
    workspaceId: 'workspace',
    start: null,
    end: null,
  );
  const root = ProjectModel(
    id: 'root',
    code: 'RT',
    name: 'Root',
    workspaceId: 'workspace',
    start: null,
    end: null,
    children: <ProjectModel>[child],
  );
  const other = ProjectModel(
    id: 'other',
    code: 'OT',
    name: 'Other',
    workspaceId: 'workspace',
    start: null,
    end: null,
  );

  test('filters on the server with parent and child project ids', () async {
    final repository = _TasksRepository(<ProjectTaskModel>[
      _task('root-task', 'root'),
      _task('child-task', 'child'),
      _task('other-task', 'other'),
    ]);
    final cubit = MyTasksCubit(
      repository: repository,
      fieldsStorage: _FieldsStorage(),
    );

    await cubit.configure(
      userId: 'user-1',
      projects: const <ProjectModel>[root, other],
    );
    await cubit.selectProjects(<String>{'root'});

    expect(repository.assigneeId, 'user-1');
    expect(repository.projectIds, containsAll(<String>['root', 'child']));
    expect(cubit.state.tasks.map((task) => task.id), <String>[
      'root-task',
      'child-task',
    ]);
    await cubit.close();
  });

  test(
    'all projects stays within current workspace including children',
    () async {
      final repository = _TasksRepository([
        _task('root-task', 'root'),
        _task('child-task', 'child'),
        _task('foreign-task', 'another-workspace-project'),
      ])..ignoreScope = true;
      final cubit = MyTasksCubit(
        repository: repository,
        fieldsStorage: _FieldsStorage(),
      );
      addTearDown(cubit.close);
      await cubit.configure(userId: 'user', projects: const [root]);
      expect(repository.projectIds, unorderedEquals(['root', 'child']));
      expect(cubit.state.tasks.map((task) => task.id), [
        'root-task',
        'child-task',
      ]);
    },
  );

  test('workspace without projects never loads unscoped tasks', () async {
    final repository = _TasksRepository([_task('foreign-task', 'foreign')]);
    final cubit = MyTasksCubit(
      repository: repository,
      fieldsStorage: _FieldsStorage(),
    );
    addTearDown(cubit.close);
    await cubit.configure(userId: 'user', projects: const []);
    expect(repository.assigneeId, isNull);
    expect(cubit.state.tasks, isEmpty);
  });

  test('optimistically updates progress and rolls back on failure', () async {
    final repository = _TasksRepository(<ProjectTaskModel>[
      _task('task', 'root', progress: 20),
    ])..updateCompleter = Completer<void>();
    final cubit = MyTasksCubit(
      repository: repository,
      fieldsStorage: _FieldsStorage(),
    );
    await cubit.configure(
      userId: 'user-1',
      projects: const <ProjectModel>[root],
    );

    final update = cubit.toggleTask(cubit.state.tasks.single);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.tasks.single.progress, 100);
    expect(cubit.state.updatingTaskIds, contains('task'));

    repository.updateCompleter!.completeError(
      const MyTasksException('Ошибка обновления'),
    );
    await update;
    expect(cubit.state.tasks.single.progress, 20);
    expect(cubit.state.actionErrorMessage, 'Ошибка обновления');
    expect(repository.updatedProgress, 100);
    await cubit.close();
  });

  for (final failSave in [false, true]) {
    test(
      'filter changes wait for saving and use the latest selection (failure: $failSave)',
      () async {
        final repository = _TasksRepository([
          _task('task', 'root'),
          _task('other-task', 'other'),
        ])..updateCompleter = Completer<void>();
        final cubit = MyTasksCubit(
          repository: repository,
          fieldsStorage: _FieldsStorage(),
        );
        addTearDown(cubit.close);
        await cubit.configure(userId: 'user', projects: const [root, other]);
        final pending = cubit.toggleTask(cubit.state.tasks.first);
        await cubit.selectProjects({'root'});
        await cubit.selectProjects({'other'});
        await cubit.refresh();
        expect(cubit.state.status, MyTasksStatus.loading);
        expect(repository.requestedScopes.length, 1);
        if (failSave) {
          repository.updateCompleter!.completeError(
            const MyTasksException('Save failed'),
          );
        } else {
          repository.updateCompleter!.complete();
        }
        await pending;
        expect(repository.requestedScopes.length, 2);
        expect(repository.requestedScopes.last, ['other']);
        expect(cubit.state.tasks.map((task) => task.id), ['other-task']);
        expect(cubit.state.status, MyTasksStatus.success);
        expect(cubit.state.updatingTaskIds, isEmpty);
      },
    );
  }

  test(
    'workspace changes during a failed save load the new configuration',
    () async {
      final repository = _TasksRepository([
        _task('task', 'root'),
        _task('other-task', 'other'),
      ])..updateCompleter = Completer<void>();
      final cubit = MyTasksCubit(
        repository: repository,
        fieldsStorage: _FieldsStorage(),
      );
      addTearDown(cubit.close);
      await cubit.configure(userId: 'old-user', projects: const [root]);
      final pending = cubit.toggleTask(cubit.state.tasks.single);
      await cubit.configure(userId: 'new-user', projects: const [other]);
      repository.updateCompleter!.completeError(
        const MyTasksException('Save failed'),
      );
      await pending;
      expect(repository.assigneeId, 'new-user');
      expect(repository.requestedScopes.last, ['other']);
      expect(cubit.state.tasks.map((task) => task.id), ['other-task']);
      expect(cubit.state.projects, [other]);
    },
  );

  test(
    'queued refresh runs once after every concurrent save finishes',
    () async {
      final repository = _TasksRepository([
        _task('task', 'root'),
        _task('other-task', 'other'),
      ]);
      repository.updateCompleters['task'] = Completer<void>();
      repository.updateCompleters['other-task'] = Completer<void>();
      final cubit = MyTasksCubit(
        repository: repository,
        fieldsStorage: _FieldsStorage(),
      );
      addTearDown(cubit.close);
      await cubit.configure(userId: 'user', projects: const [root, other]);
      final first = cubit.toggleTask(cubit.state.tasks.first);
      final second = cubit.toggleTask(cubit.state.tasks.last);
      await cubit.selectProjects({'other'});
      await cubit.refresh();
      repository.updateCompleters['task']!.complete();
      await first;
      expect(repository.requestedScopes.length, 1);
      expect(cubit.state.updatingTaskIds, {'other-task'});
      repository.updateCompleters['other-task']!.complete();
      await second;
      expect(repository.requestedScopes.length, 2);
      expect(cubit.state.tasks.map((task) => task.id), ['other-task']);
    },
  );

  test('failed queued load shows an error and can be retried', () async {
    final repository = _TasksRepository([
      _task('task', 'root'),
      _task('other-task', 'other'),
    ])..updateCompleter = Completer<void>();
    final cubit = MyTasksCubit(
      repository: repository,
      fieldsStorage: _FieldsStorage(),
    );
    addTearDown(cubit.close);
    await cubit.configure(userId: 'user', projects: const [root, other]);
    final pending = cubit.toggleTask(cubit.state.tasks.first);
    await cubit.selectProjects({'other'});
    repository.loadError = const MyTasksException('Load failed');
    repository.updateCompleter!.complete();
    await pending;
    expect(cubit.state.status, MyTasksStatus.failure);
    expect(cubit.state.errorMessage, 'Load failed');
    repository.loadError = null;
    await cubit.refresh();
    expect(cubit.state.status, MyTasksStatus.success);
    expect(cubit.state.tasks.map((task) => task.id), ['other-task']);
  });

  test('closing while a refresh is queued never starts another load', () async {
    final repository = _TasksRepository([_task('task', 'root')])
      ..updateCompleter = Completer<void>();
    final cubit = MyTasksCubit(
      repository: repository,
      fieldsStorage: _FieldsStorage(),
    );
    await cubit.configure(userId: 'user', projects: const [root, other]);
    final pending = cubit.toggleTask(cubit.state.tasks.single);
    await cubit.selectProjects({'other'});
    await cubit.close();
    repository.updateCompleter!.complete();
    await pending;
    expect(repository.requestedScopes.length, 1);
  });

  test(
    'late previous load cannot overwrite the deferred filter result',
    () async {
      final repository = _TasksRepository([
        _task('task', 'root'),
        _task('other-task', 'other'),
      ])..updateCompleter = Completer<void>();
      final cubit = MyTasksCubit(
        repository: repository,
        fieldsStorage: _FieldsStorage(),
      );
      addTearDown(cubit.close);
      await cubit.configure(userId: 'user', projects: const [root, other]);
      final oldResponse = Completer<List<ProjectTaskModel>>();
      repository.nextLoad = oldResponse;
      final oldLoad = cubit.refresh();
      final pending = cubit.toggleTask(cubit.state.tasks.first);
      await cubit.selectProjects({'other'});
      repository.updateCompleter!.complete();
      await pending;
      oldResponse.complete([_task('stale-task', 'root')]);
      await oldLoad;
      expect(repository.requestedScopes.length, 3);
      expect(cubit.state.tasks.map((task) => task.id), ['other-task']);
      expect(cubit.state.selectedProjectIds, {'other'});
    },
  );

  test('loads and persists optional fields', () async {
    final storage = _FieldsStorage(<TaskExtraField>{TaskExtraField.id});
    final cubit = MyTasksCubit(
      repository: _TasksRepository(const <ProjectTaskModel>[]),
      fieldsStorage: storage,
    );

    await cubit.initializeFields();
    expect(cubit.state.visibleFields, <TaskExtraField>{TaskExtraField.id});
    await cubit.toggleField(TaskExtraField.epics);
    expect(storage.saved, <TaskExtraField>{
      TaskExtraField.id,
      TaskExtraField.epics,
    });
    await cubit.close();
  });
}

ProjectTaskModel _task(String id, String projectId, {double? progress}) {
  return ProjectTaskModel(
    id: id,
    displayId: id,
    title: id,
    projectId: projectId,
    status: 'TODO',
    progress: progress,
  );
}

class _TasksRepository implements MyTasksRepository {
  _TasksRepository(this.tasks);

  final List<ProjectTaskModel> tasks;
  bool ignoreScope = false;
  String? assigneeId;
  List<String> projectIds = const <String>[];
  Completer<void>? updateCompleter;
  final updateCompleters = <String, Completer<void>>{};
  final requestedScopes = <List<String>>[];
  MyTasksException? loadError;
  Completer<List<ProjectTaskModel>>? nextLoad;
  int? updatedProgress;

  @override
  Future<List<ProjectTaskModel>> getTasks({
    required String assigneeId,
    List<String> projectIds = const <String>[],
  }) async {
    this.assigneeId = assigneeId;
    this.projectIds = projectIds;
    requestedScopes.add([...projectIds]);
    if (loadError != null) throw loadError!;
    final pending = nextLoad;
    nextLoad = null;
    if (pending != null) return pending.future;
    if (projectIds.isEmpty || ignoreScope) return tasks;
    return tasks
        .where((task) => projectIds.contains(task.projectId))
        .toList(growable: false);
  }

  @override
  Future<List<KanbanColumnModel>> getKanbanColumns(String projectId) async {
    return const <KanbanColumnModel>[
      KanbanColumnModel(id: 'todo', name: 'К работе', statusMap: 'TODO'),
    ];
  }

  @override
  Future<void> updateProgress(String taskId, int progress, {String? status}) {
    updatedProgress = progress;
    return updateCompleters[taskId]?.future ??
        updateCompleter?.future ??
        Future<void>.value();
  }
}

class _FieldsStorage implements MyTaskFieldsStorage {
  _FieldsStorage([
    this.fields = const <TaskExtraField>{
      TaskExtraField.id,
      TaskExtraField.column,
      TaskExtraField.epics,
    },
  ]);

  Set<TaskExtraField> fields;
  Set<TaskExtraField>? saved;

  @override
  Future<Set<TaskExtraField>> read() async => fields;

  @override
  Future<void> save(Set<TaskExtraField> fields) async {
    saved = Set<TaskExtraField>.from(fields);
  }
}
