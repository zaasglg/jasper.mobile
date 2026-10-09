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
  }) => throw UnimplementedError();
}
