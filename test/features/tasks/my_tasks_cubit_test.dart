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
  String? assigneeId;
  List<String> projectIds = const <String>[];
  Completer<void>? updateCompleter;
  int? updatedProgress;

  @override
  Future<List<ProjectTaskModel>> getTasks({
    required String assigneeId,
    List<String> projectIds = const <String>[],
  }) async {
    this.assigneeId = assigneeId;
    this.projectIds = projectIds;
    if (projectIds.isEmpty) return tasks;
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
  Future<void> updateProgress(String taskId, int progress) {
    updatedProgress = progress;
    return updateCompleter?.future ?? Future<void>.value();
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
