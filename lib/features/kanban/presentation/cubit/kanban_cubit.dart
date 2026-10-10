import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../projects/data/models/project_task_model.dart';
import '../../../tasks/data/models/kanban_column_model.dart';
import '../../domain/entities/kanban_board_data.dart';
import '../../domain/entities/kanban_board_cache.dart';
import '../../domain/repositories/kanban_repository.dart';
import '../../domain/utils/kanban_utils.dart';
import 'kanban_state.dart';

class KanbanCubit extends Cubit<KanbanState> {
  KanbanCubit(this._repository, {KanbanBoardCache? cache})
    : _cache = cache ?? KanbanBoardCache(),
      super(const KanbanState());

  final KanbanRepository _repository;
  final KanbanBoardCache _cache;
  int _loadRevision = 0;

  Future<void> load(String projectId, {bool refresh = false}) async {
    if (projectId.isEmpty) return;
    final revision = ++_loadRevision;
    final cached = _cache.read(projectId);
    if (cached != null && !refresh) {
      emit(
        state.copyWith(
          status: KanbanStatus.success,
          projectId: projectId,
          columns: sortKanbanColumns(cached.columns),
          tasks: cached.tasks,
          clearError: true,
        ),
      );
    } else {
      emit(
        KanbanState(
          status: KanbanStatus.loading,
          projectId: projectId,
          columns: cached?.columns ?? const [],
          tasks: cached?.tasks ?? const [],
        ),
      );
    }
    try {
      final board = await _repository.loadBoard(projectId);
      if (isClosed || revision != _loadRevision) return;
      _cache.write(projectId, board);
      emit(
        state.copyWith(
          status: KanbanStatus.success,
          projectId: projectId,
          columns: sortKanbanColumns(board.columns),
          tasks: board.tasks,
          clearError: true,
        ),
      );
    } on KanbanException catch (error) {
      if (isClosed ||
          revision != _loadRevision ||
          error.message == 'Запрос отменён.') {
        return;
      }
      emit(
        state.copyWith(
          status: cached == null ? KanbanStatus.failure : KanbanStatus.success,
          errorMessage: cached == null ? error.message : null,
          actionErrorMessage: cached != null ? error.message : null,
          actionRevision: cached != null
              ? state.actionRevision + 1
              : state.actionRevision,
        ),
      );
    }
  }

  void setSearch(String value) => emit(state.copyWith(search: value));

  void setPriorityFilter(String? value) => emit(
    state.copyWith(priorityFilter: value, clearPriorityFilter: value == null),
  );

  Future<void> toggleCompleted(ProjectTaskModel task) async {
    if (state.movingTaskIds.isNotEmpty) return;
    final projectId = state.projectId;
    final progress = task.isDone ? 0 : 100;
    final reopenedStatus = task.isDone && task.status.toUpperCase() == 'DONE'
        ? (state.columns
                  .where((column) => column.statusMap.toUpperCase() != 'DONE')
                  .firstOrNull
                  ?.statusMap ??
              'TODO')
        : null;
    final updated = task.copyWith(
      progress: progress.toDouble(),
      status: reopenedStatus,
    );
    emit(
      state.copyWith(
        tasks: state.tasks
            .map((item) => item.id == task.id ? updated : item)
            .toList(),
        movingTaskIds: {task.id},
        clearActionError: true,
      ),
    );
    try {
      await _repository.updateCompletion(
        task.id,
        progress: progress,
        status: reopenedStatus,
      );
      if (isClosed || state.projectId != projectId) return;
      _cache.write(
        projectId,
        KanbanBoardData(columns: state.columns, tasks: state.tasks),
      );
      emit(state.copyWith(movingTaskIds: {}));
    } catch (error) {
      if (isClosed || state.projectId != projectId) return;
      emit(
        state.copyWith(
          tasks: state.tasks
              .map((item) => item.id == task.id ? task : item)
              .toList(),
          movingTaskIds: {},
        ),
      );
      _actionError(
        error is KanbanException
            ? error.message
            : 'Не удалось обновить завершение задачи.',
      );
    }
  }

  Future<void> archiveTask(ProjectTaskModel task) async {
    if (state.movingTaskIds.isNotEmpty) return;
    final projectId = state.projectId;
    final oldTasks = state.tasks;
    emit(
      state.copyWith(
        tasks: state.tasks.where((item) => item.id != task.id).toList(),
        movingTaskIds: {task.id},
        clearActionError: true,
      ),
    );
    try {
      await _repository.archiveTask(task.id);
      if (isClosed || state.projectId != projectId) return;
      _cache.write(
        projectId,
        KanbanBoardData(columns: state.columns, tasks: state.tasks),
      );
      emit(state.copyWith(movingTaskIds: {}));
    } catch (error) {
      if (isClosed || state.projectId != projectId) return;
      // Restore only the archived card, preserving other edits made meanwhile.
      emit(
        state.copyWith(
          tasks: [
            for (final item in oldTasks)
              if (item.id == task.id) item,
            ...state.tasks,
          ],
          movingTaskIds: {},
        ),
      );
      _actionError(
        error is KanbanException
            ? error.message
            : 'Не удалось архивировать задачу.',
      );
    }
  }

  Future<void> moveTask(
    ProjectTaskModel task,
    String targetStatus,
    int position,
  ) async {
    if (state.movingTaskIds.contains(task.id)) return;
    final oldTasks = state.tasks;
    final updated = moveKanbanTask(
      tasks: oldTasks,
      taskId: task.id,
      projectId: state.projectId,
      targetStatus: targetStatus,
      targetPosition: position,
    );
    emit(
      state.copyWith(
        tasks: updated,
        movingTaskIds: <String>{...state.movingTaskIds, task.id},
        clearActionError: true,
      ),
    );
    try {
      await _repository.moveTask(
        taskId: task.id,
        projectId: state.projectId,
        status: targetStatus,
        position: position,
      );
      if (isClosed) return;
      _cache.write(
        state.projectId,
        KanbanBoardData(columns: state.columns, tasks: state.tasks),
      );
      emit(
        state.copyWith(
          movingTaskIds: {...state.movingTaskIds}..remove(task.id),
        ),
      );
    } on KanbanException catch (error) {
      if (isClosed) return;
      final message =
          error.statusCode == 403 && targetStatus.toUpperCase() == 'DONE'
          ? 'Недостаточно прав для переноса задачи в «Готово».'
          : error.message;
      emit(
        state.copyWith(
          tasks: oldTasks,
          movingTaskIds: {...state.movingTaskIds}..remove(task.id),
          actionErrorMessage: message,
          actionRevision: state.actionRevision + 1,
        ),
      );
    }
  }

  Future<void> createTask(String status, String title, String priority) async {
    try {
      final task = await _repository.createTask(
        projectId: state.projectId,
        title: title,
        status: status,
        priority: priority,
      );
      if (isClosed) return;
      final tasks = <ProjectTaskModel>[...state.tasks, task];
      _cache.write(
        state.projectId,
        KanbanBoardData(columns: state.columns, tasks: tasks),
      );
      emit(state.copyWith(tasks: tasks));
    } on KanbanException catch (error) {
      _actionError(error.message);
    }
  }

  Future<void> createColumn(String name, int? wip) async {
    try {
      final column = await _repository.createColumn(
        projectId: state.projectId,
        name: name,
        order: state.columns.length,
        wip: wip,
      );
      if (isClosed) return;
      final columns = sortKanbanColumns([...state.columns, column]);
      emit(state.copyWith(columns: columns));
    } on KanbanException catch (error) {
      _actionError(error.message);
    }
  }

  Future<void> updateColumn(
    KanbanColumnModel column,
    String name,
    int? wip,
  ) async {
    try {
      final updated = await _repository.updateColumn(
        columnId: column.id,
        name: name,
        wip: wip,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          columns: <KanbanColumnModel>[
            for (final item in state.columns)
              if (item.id == column.id) updated else item,
          ],
        ),
      );
    } on KanbanException catch (error) {
      _actionError(error.message);
    }
  }

  Future<void> archiveColumn(KanbanColumnModel column) async {
    try {
      await _repository.archiveColumn(column.id);
      if (isClosed) return;
      emit(
        state.copyWith(
          columns: state.columns
              .where((item) => item.id != column.id)
              .toList(growable: false),
        ),
      );
    } on KanbanException catch (error) {
      _actionError(error.message);
    }
  }

  Future<void> deleteColumn(KanbanColumnModel column) async {
    try {
      await _repository.deleteColumn(column.id);
      if (isClosed) return;
      emit(
        state.copyWith(
          columns: state.columns
              .where((item) => item.id != column.id)
              .toList(growable: false),
        ),
      );
    } on KanbanException catch (error) {
      _actionError(error.message);
    }
  }

  Future<void> moveColumn(KanbanColumnModel column, int offset) async {
    final oldColumns = state.columns;
    final from = oldColumns.indexWhere((item) => item.id == column.id);
    if (from < 0) return;
    final to = (from + offset).clamp(0, oldColumns.length - 1);
    if (from == to) return;
    final columns = oldColumns.toList(growable: true);
    columns.insert(to, columns.removeAt(from));
    final reordered = <KanbanColumnModel>[
      for (var index = 0; index < columns.length; index++)
        columns[index].copyWith(order: index),
    ];
    emit(state.copyWith(columns: reordered));
    try {
      await _repository.reorderColumns(
        state.projectId,
        reordered.map((item) => item.id).toList(growable: false),
      );
    } on KanbanException catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          columns: oldColumns,
          actionErrorMessage: error.message,
          actionRevision: state.actionRevision + 1,
        ),
      );
    }
  }

  void _actionError(String message) {
    if (isClosed) return;
    emit(
      state.copyWith(
        actionErrorMessage: message,
        actionRevision: state.actionRevision + 1,
      ),
    );
  }

  @override
  Future<void> close() {
    _repository.cancelPendingLoads();
    return super.close();
  }
}
