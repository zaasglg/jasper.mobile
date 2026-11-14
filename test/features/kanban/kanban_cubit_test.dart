import 'package:jospar/features/kanban/data/models/task_translation.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/kanban/domain/entities/kanban_board_data.dart';
import 'package:jospar/features/kanban/domain/repositories/kanban_repository.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_cubit.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_state.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/tasks/data/models/kanban_column_model.dart';

void main() {
  const todo = KanbanColumnModel(
    id: 'todo',
    name: 'К работе',
    statusMap: 'TODO',
    order: 0,
    wip: 1,
  );
  const task = ProjectTaskModel(
    id: 'task',
    projectId: 'project',
    status: 'TODO',
  );

  test('late board response cannot undo a move or clear its lock', () async {
    final repository = _RaceRepository();
    final cubit = KanbanCubit(repository);
    addTearDown(cubit.close);
    await cubit.load('project');
    final staleBoard = await repository.loadBoard('project');
    final gate = Completer<KanbanBoardData>();
    repository.nextLoad = gate;
    final refresh = cubit.load('project', refresh: true);
    final moving = cubit.moveTask(task, 'DONE', 0);
    gate.complete(staleBoard);
    await refresh;
    expect(
      cubit.state.tasks.firstWhere((task) => task.id == 'task').status,
      'DONE',
    );
    expect(cubit.state.movingTaskIds, {'task'});
    final loads = repository.loads;
    await cubit.load('project', refresh: true);
    expect(repository.loads, loads);
    repository.moves['task']!.complete();
    await moving;
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.tasks.firstWhere((t) => t.id == 'task').status, 'DONE');
    expect(cubit.state.movingTaskIds, isEmpty);
    expect(repository.loads, loads + 1);
  });

  test(
    'translation does not block another task and preserves its lock',
    () async {
      final repository = _RaceRepository();
      final cubit = KanbanCubit(repository);
      addTearDown(cubit.close);
      await cubit.load('project');
      final translation = cubit.translateTask(task, 'w', 'ru');
      final other = cubit.state.tasks.last;
      final move = cubit.moveTask(other, 'DONE', 0);
      expect(repository.moves.keys, contains('other'));
      expect(cubit.state.movingTaskIds, {'task', 'other'});
      repository.translation.complete(
        const TaskTranslation(title: 'T', description: 'D'),
      );
      await translation;
      expect(cubit.state.movingTaskIds, {'other'});
      repository.moves['other']!.complete();
      await move;
      expect(cubit.state.movingTaskIds, isEmpty);
    },
  );

  test('failed move preserves another successful move', () async {
    final repository = _RaceRepository();
    final cubit = KanbanCubit(repository);
    addTearDown(cubit.close);
    await cubit.load('project');
    final first = cubit.moveTask(task, 'DONE', 0);
    final second = cubit.moveTask(
      cubit.state.tasks.firstWhere((t) => t.id == 'other'),
      'DONE',
      0,
    );
    repository.moves['other']!.complete();
    await second;
    repository.moves['task']!.completeError(
      const KanbanException('Ошибка сети'),
    );
    await first;
    expect(cubit.state.tasks.firstWhere((t) => t.id == 'task').status, 'TODO');
    expect(cubit.state.tasks.firstWhere((t) => t.id == 'other').status, 'DONE');
    expect(cubit.state.movingTaskIds, isEmpty);
  });

  test('deleted column and missing task are not sent to the server', () async {
    final repository = _RaceRepository();
    final cubit = KanbanCubit(repository);
    addTearDown(cubit.close);
    await cubit.load('project');
    await cubit.deleteColumn(cubit.state.columns.last);
    await cubit.moveTask(task, 'DONE', 0);
    await cubit.moveTask(
      const ProjectTaskModel(
        id: 'missing',
        projectId: 'project',
        status: 'TODO',
      ),
      'TODO',
      0,
    );
    expect(repository.moves, isEmpty);
    expect(cubit.state.actionErrorMessage, contains('Колонка'));
  });

  test('unexpected move failure clears its task lock', () async {
    final repository = _RaceRepository();
    final cubit = KanbanCubit(repository);
    addTearDown(cubit.close);
    await cubit.load('project');
    final pending = cubit.moveTask(task, 'DONE', 0);
    repository.moves['task']!.completeError(StateError('interceptor failed'));
    await pending;
    expect(cubit.state.movingTaskIds, isEmpty);
    expect(cubit.state.tasks.firstWhere((t) => t.id == 'task').status, 'TODO');
    expect(cubit.state.actionErrorMessage, isNotNull);
  });

  test('late failed move cannot contaminate a different project', () async {
    final repository = _RaceRepository();
    final cubit = KanbanCubit(repository);
    addTearDown(cubit.close);
    await cubit.load('project');
    final pending = cubit.moveTask(task, 'DONE', 0);
    await cubit.load('next');
    repository.moves['task']!.completeError(
      const KanbanException('Ошибка сети'),
    );
    await pending;
    expect(cubit.state.projectId, 'next');
    expect(cubit.state.tasks.every((task) => task.projectId == 'next'), isTrue);
    expect(cubit.state.movingTaskIds, isEmpty);
    expect(cubit.state.actionErrorMessage, isNull);
  });

  test('completion toggles immediately and rolls back after failure', () async {
    final completer = Completer<void>();
    final cubit = KanbanCubit(_Repository(moveCompleter: completer));
    await cubit.load('project');
    final pending = cubit.toggleCompleted(task);
    expect(cubit.state.tasks.single.isDone, isTrue);
    expect(cubit.state.tasks.single.status, 'TODO');
    expect(cubit.state.movingTaskIds, {'task'});
    completer.completeError(const KanbanException('Ошибка сети'));
    await pending;
    expect(cubit.state.tasks.single.isDone, isFalse);
    expect(cubit.state.actionErrorMessage, 'Ошибка сети');
    expect(cubit.state.movingTaskIds, isEmpty);
    await cubit.close();
  });

  test('saves completion and allows reopening', () async {
    final cubit = KanbanCubit(_Repository());
    await cubit.load('project');
    await cubit.toggleCompleted(task);
    expect(cubit.state.tasks.single.progress, 100);
    expect(cubit.state.movingTaskIds, isEmpty);
    await cubit.toggleCompleted(cubit.state.tasks.single);
    expect(cubit.state.tasks.single.isDone, isFalse);
    expect(cubit.state.tasks.single.progress, 0);
    await cubit.close();
  });

  test('shows WIP warning when column exceeds its limit', () {
    const state = KanbanState(
      columns: [todo],
      tasks: [
        task,
        ProjectTaskModel(id: 'second', projectId: 'project', status: 'TODO'),
      ],
    );
    expect(state.exceedsWip(todo), isTrue);
  });

  test('optimistically moves and rolls back after an error', () async {
    final completer = Completer<void>();
    final repository = _Repository(moveCompleter: completer);
    final cubit = KanbanCubit(repository);
    await cubit.load('project');

    final future = cubit.moveTask(task, 'DONE', 0);
    expect(cubit.state.tasks.single.status, 'DONE');
    completer.completeError(const KanbanException('Ошибка сети'));
    await future;

    expect(cubit.state.tasks.single.status, 'TODO');
    expect(cubit.state.actionErrorMessage, 'Ошибка сети');
    await cubit.close();
  });

  test(
    'archives optimistically and restores the task after a failure',
    () async {
      final completer = Completer<void>();
      final cubit = KanbanCubit(_Repository(moveCompleter: completer));
      await cubit.load('project');
      final pending = cubit.archiveTask(task);
      expect(cubit.state.tasks, isEmpty);
      completer.completeError(const KanbanException('Архив недоступен'));
      await pending;
      expect(cubit.state.tasks.single.id, task.id);
      expect(cubit.state.actionErrorMessage, 'Архив недоступен');
      expect(cubit.state.movingTaskIds, isEmpty);
      await cubit.close();
    },
  );

  test(
    'successful archive removes task and clears the pending state',
    () async {
      final cubit = KanbanCubit(_Repository());
      await cubit.load('project');
      await cubit.archiveTask(task);
      expect(cubit.state.tasks, isEmpty);
      expect(cubit.state.movingTaskIds, isEmpty);
      await cubit.close();
    },
  );

  test('explains a 403 response when moving to DONE', () async {
    final repository = _Repository(
      moveError: const KanbanException('Forbidden', statusCode: 403),
    );
    final cubit = KanbanCubit(repository);
    await cubit.load('project');

    await cubit.moveTask(task, 'DONE', 0);

    expect(cubit.state.tasks.single.status, 'TODO');
    expect(cubit.state.actionErrorMessage, contains('Недостаточно прав'));
    await cubit.close();
  });
}

class _Repository implements KanbanRepository {
  @override
  Future<void> deleteTask(String taskId) async {
    if (moveCompleter != null) await moveCompleter!.future;
  }

  @override
  Future<ProjectTaskModel> duplicateTask(String taskId) async =>
      const ProjectTaskModel(id: 'copy', projectId: 'project', status: 'TODO');
  @override
  Future<ProjectTaskModel> updateCover(
    String taskId,
    Map<String, dynamic>? cover,
  ) async {
    if (moveCompleter != null) await moveCompleter!.future;
    return const ProjectTaskModel(
      id: 'task',
      projectId: 'project',
      status: 'TODO',
      detail: '{"cover":{"type":"color","color":"#fff"}}',
    );
  }

  @override
  Future<TaskTranslation> translateTask(
    String taskId,
    String workspaceId,
    String language,
  ) async => const TaskTranslation(title: 'Аударма', description: 'Мәтін');
  @override
  Future<ProjectTaskModel> applyTranslation(
    String taskId,
    TaskTranslation translation,
  ) async => ProjectTaskModel(
    id: taskId,
    projectId: 'project',
    status: 'TODO',
    title: translation.title,
  );

  _Repository({this.moveCompleter, this.moveError});

  final Completer<void>? moveCompleter;
  final KanbanException? moveError;

  @override
  Future<KanbanBoardData> loadBoard(
    String projectId, {
    String? search,
    int take = 100,
    int skip = 0,
  }) async => const KanbanBoardData(
    columns: [
      KanbanColumnModel(
        id: 'todo',
        name: 'К работе',
        statusMap: 'TODO',
        order: 0,
      ),
      KanbanColumnModel(
        id: 'done',
        name: 'Готово',
        statusMap: 'DONE',
        order: 1,
      ),
    ],
    tasks: [ProjectTaskModel(id: 'task', projectId: 'project', status: 'TODO')],
  );

  @override
  Future<void> moveTask({
    required String taskId,
    required String projectId,
    required String status,
    required int position,
  }) async {
    if (moveError != null) throw moveError!;
    if (moveCompleter != null) await moveCompleter!.future;
  }

  @override
  Future<void> updateCompletion(
    String taskId, {
    required int progress,
    String? status,
  }) async {
    if (moveCompleter != null) await moveCompleter!.future;
  }

  @override
  void cancelPendingLoads() {}

  @override
  Future<void> archiveColumn(String columnId) async {}

  @override
  Future<void> archiveTask(String taskId) async {
    if (moveCompleter != null) await moveCompleter!.future;
  }

  @override
  Future<ProjectTaskModel> createTask({
    required String projectId,
    required String title,
    required String status,
    required String priority,
    List<String> epicIds = const [],
  }) => throw UnimplementedError();

  @override
  Future<KanbanColumnModel> createColumn({
    required String projectId,
    required String name,
    required int order,
    int? wip,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteColumn(String columnId) async {}

  @override
  Future<void> reorderColumns(String projectId, List<String> ids) async {}

  @override
  Future<KanbanColumnModel> updateColumn({
    required String columnId,
    required String name,
    int? wip,
    String? color,
  }) => throw UnimplementedError();
}

class _RaceRepository extends _Repository {
  Completer<KanbanBoardData>? nextLoad;
  final translation = Completer<TaskTranslation>();
  final moves = <String, Completer<void>>{};
  final statuses = <String, String>{};
  int loads = 0;

  @override
  Future<KanbanBoardData> loadBoard(
    String projectId, {
    String? search,
    int take = 100,
    int skip = 0,
  }) async {
    loads++;
    final gate = nextLoad;
    nextLoad = null;
    if (gate != null) return gate.future;
    final original = await super.loadBoard(projectId);
    return KanbanBoardData(
      columns: original.columns,
      tasks: [
        ProjectTaskModel(
          id: 'task',
          projectId: projectId,
          status: statuses['task'] ?? 'TODO',
        ),
        ProjectTaskModel(
          id: 'other',
          projectId: projectId,
          status: statuses['other'] ?? 'TODO',
          order: 1,
        ),
      ],
    );
  }

  @override
  Future<TaskTranslation> translateTask(
    String taskId,
    String workspaceId,
    String language,
  ) => translation.future;

  @override
  Future<void> moveTask({
    required String taskId,
    required String projectId,
    required String status,
    required int position,
  }) async {
    final gate = Completer<void>();
    moves[taskId] = gate;
    await gate.future;
    statuses[taskId] = status;
  }
}
