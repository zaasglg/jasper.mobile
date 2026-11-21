import 'dart:async';

import '../../../assistant/data/services/assistant_task_changes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../data/models/task_translation.dart';
import '../../../tasks/data/services/task_changes.dart';
import '../../domain/entities/task_move_target.dart';
import '../../domain/repositories/task_move_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../projects/data/models/project_task_model.dart';
import '../../../tasks/domain/entities/kanban_column_model.dart';
import '../../../tasks/domain/utils/task_completion.dart';
import '../../domain/entities/kanban_board_data.dart';
import '../../domain/entities/kanban_board_cache.dart';
import '../../domain/repositories/kanban_repository.dart';
import '../../domain/utils/kanban_utils.dart';
import 'kanban_state.dart';

class KanbanCubit extends Cubit<KanbanState> {
  KanbanCubit(
    this._repository, {
    KanbanBoardCache? cache,
    TaskMoveRepository? taskMoveRepository,
  }) : _cache = cache ?? KanbanBoardCache(),
       _taskMoveRepository = taskMoveRepository,
       super(const KanbanState()) {
    assistantTaskChanges.addListener(_onAiTasksChanged);
    authSession.addListener(_onSessionChanged);
  }

  bool _sessionInvalidated = false;
  void _onSessionChanged() {
    _sessionInvalidated = true;
    _loadRevision++;
    _cache.clear();
    _repository.cancelPendingLoads();
    if (!isClosed) emit(const KanbanState());
  }

  void _onAiTasksChanged() {
    if (_publishingTaskChange) return;
    _cache.clear();
    if (!isClosed && state.projectId.isNotEmpty) {
      load(state.projectId, refresh: true);
    }
  }

  final KanbanRepository _repository;
  final TaskMoveRepository? _taskMoveRepository;
  bool _publishingTaskChange = false;
  final KanbanBoardCache _cache;
  int _loadRevision = 0;
  int _projectRevision = 0;
  String? _loadingProject;
  bool _refreshAfterOperations = false;

  bool _canUpdateTask(ProjectTaskModel task) =>
      !_sessionInvalidated &&
      !isClosed &&
      !state.movingTaskIds.contains(task.id) &&
      state.tasks.any((item) => item.id == task.id);

  int _beginTaskOperation() {
    // A response started before this edit must never replace it.
    if (_loadingProject == state.projectId) {
      _loadRevision++;
      _loadingProject = null;
      _repository.cancelPendingLoads();
      _refreshAfterOperations = true;
    }
    if (state.status == KanbanStatus.loading) {
      emit(state.copyWith(status: KanbanStatus.success));
    }
    return _projectRevision;
  }

  bool _isCurrentOperation(int revision) =>
      !isClosed && !_sessionInvalidated && revision == _projectRevision;

  Set<String> _withoutTask(String id) => {...state.movingTaskIds}..remove(id);

  void _finishTaskOperation() {
    if (isClosed || _sessionInvalidated || state.movingTaskIds.isNotEmpty) {
      return;
    }
    _cache.write(
      state.projectId,
      KanbanBoardData(columns: state.columns, tasks: state.tasks),
    );
    if (_refreshAfterOperations) {
      _refreshAfterOperations = false;
      unawaited(load(state.projectId, refresh: true));
    }
  }

  Future<void> load(String projectId, {bool refresh = false}) async {
    if (_sessionInvalidated || isClosed || projectId.isEmpty) return;
    if (projectId == state.projectId && state.movingTaskIds.isNotEmpty) {
      _refreshAfterOperations = true;
      return;
    }
    if (projectId != state.projectId) {
      _projectRevision++;
      _refreshAfterOperations = false;
    }
    _loadingProject = projectId;
    final revision = ++_loadRevision;
    final previous = state;
    final keepContent =
        previous.projectId == projectId &&
        previous.status == KanbanStatus.success;
    final cached = _cache.read(projectId);
    if (keepContent) {
      emit(state.copyWith(clearError: true));
    } else if (cached != null && !refresh) {
      emit(
        KanbanState(
          status: KanbanStatus.success,
          projectId: projectId,
          columns: sortKanbanColumns(cached.columns),
          tasks: cached.tasks,
          epicFilterIds: previous.projectId == projectId
              ? previous.epicFilterIds
              : const <String>{},
        ),
      );
    } else {
      emit(
        KanbanState(
          status: KanbanStatus.loading,
          projectId: projectId,
          columns: cached?.columns ?? const [],
          tasks: cached?.tasks ?? const [],
          epicFilterIds: previous.projectId == projectId
              ? previous.epicFilterIds
              : const <String>{},
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
          status: cached == null && !keepContent
              ? KanbanStatus.failure
              : KanbanStatus.success,
          errorMessage: cached == null && !keepContent ? error.message : null,
          actionErrorMessage: cached != null || keepContent
              ? error.message
              : null,
          actionRevision: cached != null || keepContent
              ? state.actionRevision + 1
              : state.actionRevision,
        ),
      );
    } finally {
      if (revision == _loadRevision) _loadingProject = null;
    }
  }

  void setSearch(String value) => emit(state.copyWith(search: value));

  void setEpicFilter(Set<String> ids) =>
      emit(state.copyWith(epicFilterIds: Set<String>.unmodifiable(ids)));

  void setPriorityFilter(String? value) => emit(
    state.copyWith(priorityFilter: value, clearPriorityFilter: value == null),
  );

  Future<void> toggleCompleted(ProjectTaskModel task) async {
    if (!_canUpdateTask(task)) {
      return;
    }
    final operationRevision = _beginTaskOperation();
    final projectId = state.projectId;
    final progress = task.isDone ? 0 : 100;
    final reopenedStatus = task.isDone
        ? reopenedTaskStatus(task, state.columns)
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
        movingTaskIds: {...state.movingTaskIds, task.id},
        clearActionError: true,
      ),
    );
    try {
      await _repository.updateCompletion(
        task.id,
        progress: progress,
        status: reopenedStatus,
      );
      if (!_isCurrentOperation(operationRevision)) return;
      _cache.write(
        projectId,
        KanbanBoardData(columns: state.columns, tasks: state.tasks),
      );
      emit(state.copyWith(movingTaskIds: _withoutTask(task.id)));
    } catch (error) {
      if (!_isCurrentOperation(operationRevision)) return;
      emit(
        state.copyWith(
          tasks: state.tasks
              .map((item) => item.id == task.id ? task : item)
              .toList(),
          movingTaskIds: _withoutTask(task.id),
        ),
      );
      _actionError(
        error is KanbanException
            ? error.message
            : 'Не удалось обновить завершение задачи.',
      );
    } finally {
      if (_isCurrentOperation(operationRevision)) _finishTaskOperation();
    }
  }

  Future<void> archiveTask(ProjectTaskModel task) => _removeTask(task);
  Future<void> deleteTask(ProjectTaskModel task) =>
      _removeTask(task, delete: true);

  Future<void> _removeTask(ProjectTaskModel task, {bool delete = false}) async {
    if (!_canUpdateTask(task)) {
      return;
    }
    final operationRevision = _beginTaskOperation();
    final projectId = state.projectId;
    final oldTasks = state.tasks;
    emit(
      state.copyWith(
        tasks: state.tasks.where((item) => item.id != task.id).toList(),
        movingTaskIds: {...state.movingTaskIds, task.id},
        clearActionError: true,
      ),
    );
    try {
      if (delete) {
        await _repository.deleteTask(task.id);
      } else {
        await _repository.archiveTask(task.id);
      }
      if (!_isCurrentOperation(operationRevision)) return;
      _cache.write(
        projectId,
        KanbanBoardData(columns: state.columns, tasks: state.tasks),
      );
      emit(state.copyWith(movingTaskIds: _withoutTask(task.id)));
    } catch (error) {
      if (!_isCurrentOperation(operationRevision)) return;
      // Restore only the archived card, preserving other edits made meanwhile.
      emit(
        state.copyWith(
          tasks: [
            for (final item in oldTasks)
              if (item.id == task.id) item,
            ...state.tasks.where((item) => item.id != task.id),
          ],
          movingTaskIds: _withoutTask(task.id),
        ),
      );
      _actionError(
        error is KanbanException
            ? error.message
            : delete
            ? 'Не удалось удалить задачу.'
            : 'Не удалось архивировать задачу.',
      );
    } finally {
      if (_isCurrentOperation(operationRevision)) _finishTaskOperation();
    }
  }

  Future<bool> duplicateTask(ProjectTaskModel task) =>
      _updateCard(task, () => _repository.duplicateTask(task.id), insert: true);

  Future<bool> updateCover(
    ProjectTaskModel task,
    Map<String, dynamic>? cover,
  ) => _updateCard(task, () => _repository.updateCover(task.id, cover));

  Future<bool> applyTranslation(
    ProjectTaskModel task,
    TaskTranslation translation,
  ) => _updateCard(
    task,
    () => _repository.applyTranslation(task.id, translation),
  );

  Future<TaskTranslation?> translateTask(
    ProjectTaskModel task,
    String workspaceId,
    String language,
  ) async {
    if (!_canUpdateTask(task)) {
      return null;
    }
    final operationRevision = _beginTaskOperation();
    emit(
      state.copyWith(
        movingTaskIds: {...state.movingTaskIds, task.id},
        clearActionError: true,
      ),
    );
    try {
      final result = await _repository.translateTask(
        task.id,
        workspaceId,
        language,
      );
      if (!_isCurrentOperation(operationRevision)) return null;
      emit(state.copyWith(movingTaskIds: _withoutTask(task.id)));
      return result;
    } catch (error) {
      if (!_isCurrentOperation(operationRevision)) return null;
      emit(state.copyWith(movingTaskIds: _withoutTask(task.id)));
      _actionError(
        error is KanbanException
            ? error.message
            : 'Не удалось перевести задачу.',
      );
      return null;
    } finally {
      if (_isCurrentOperation(operationRevision)) _finishTaskOperation();
    }
  }

  Future<bool> _updateCard(
    ProjectTaskModel task,
    Future<ProjectTaskModel> Function() operation, {
    bool insert = false,
  }) async {
    if (!_canUpdateTask(task)) {
      return false;
    }
    final operationRevision = _beginTaskOperation();
    final projectId = state.projectId;
    emit(
      state.copyWith(
        movingTaskIds: {...state.movingTaskIds, task.id},
        clearActionError: true,
      ),
    );
    try {
      final updated = await operation();
      if (!_isCurrentOperation(operationRevision)) return false;
      final tasks = insert
          ? [...state.tasks, updated]
          : [
              for (final item in state.tasks)
                if (item.id == task.id) updated else item,
            ];
      _cache.write(
        projectId,
        KanbanBoardData(columns: state.columns, tasks: tasks),
      );
      emit(state.copyWith(tasks: tasks, movingTaskIds: _withoutTask(task.id)));
      return true;
    } catch (error) {
      if (!_isCurrentOperation(operationRevision)) return false;
      emit(state.copyWith(movingTaskIds: _withoutTask(task.id)));
      _actionError(
        error is KanbanException
            ? error.message
            : 'Не удалось сохранить изменения задачи.',
      );
      return false;
    } finally {
      if (_isCurrentOperation(operationRevision)) _finishTaskOperation();
    }
  }

  Future<bool> moveTask(
    ProjectTaskModel task,
    String targetStatus,
    int position,
  ) async {
    if (!_canUpdateTask(task)) return false;
    final target = state.columns
        .where(
          (column) =>
              !column.archived &&
              column.statusMap.toUpperCase() == targetStatus.toUpperCase(),
        )
        .firstOrNull;
    if (target == null) {
      _actionError('Колонка больше недоступна. Выберите другую колонку.');
      return false;
    }
    targetStatus = target.statusMap;
    final operationRevision = _beginTaskOperation();
    final projectId = state.projectId;
    final oldTasks = state.tasks;
    final originalTask = oldTasks.firstWhere((item) => item.id == task.id);
    final updated = moveKanbanTask(
      tasks: oldTasks,
      taskId: task.id,
      projectId: projectId,
      targetStatus: targetStatus,
      targetPosition: position,
    );
    emit(
      state.copyWith(
        status: KanbanStatus.success,
        tasks: updated,
        movingTaskIds: <String>{...state.movingTaskIds, task.id},
        clearActionError: true,
      ),
    );
    try {
      await _repository.moveTask(
        taskId: task.id,
        projectId: projectId,
        status: targetStatus,
        position: position,
      );
      if (!_isCurrentOperation(operationRevision)) return false;
      _cache.write(
        projectId,
        KanbanBoardData(columns: state.columns, tasks: state.tasks),
      );
      emit(
        state.copyWith(
          movingTaskIds: {...state.movingTaskIds}..remove(task.id),
        ),
      );
      return true;
    } catch (error) {
      if (!_isCurrentOperation(operationRevision)) return false;
      final message =
          error is KanbanException &&
              error.statusCode == 403 &&
              targetStatus.toUpperCase() == 'DONE'
          ? 'Недостаточно прав для переноса задачи в «Готово».'
          : error is KanbanException
          ? error.message
          : 'Не удалось переместить задачу. Попробуйте ещё раз.';
      emit(
        state.copyWith(
          tasks: moveKanbanTask(
            tasks: state.tasks,
            taskId: task.id,
            projectId: projectId,
            targetStatus: originalTask.status,
            targetPosition:
                (oldTasks
                        .where(
                          (item) =>
                              item.status.toUpperCase() ==
                              originalTask.status.toUpperCase(),
                        )
                        .toList()
                      ..sort((a, b) => a.order.compareTo(b.order)))
                    .indexWhere((item) => item.id == task.id),
          ),
          movingTaskIds: {...state.movingTaskIds}..remove(task.id),
          actionErrorMessage: message,
          actionRevision: state.actionRevision + 1,
        ),
      );
      return false;
    } finally {
      if (_isCurrentOperation(operationRevision)) _finishTaskOperation();
    }
  }

  Future<bool> transferTask(
    ProjectTaskModel task,
    TaskMoveTarget target,
  ) async {
    if (!_canUpdateTask(task)) return false;
    if (target.projectId == state.projectId) {
      final count = state.tasks
          .where(
            (item) =>
                item.id != task.id &&
                item.status.toUpperCase() == target.status.toUpperCase(),
          )
          .length;
      return moveTask(task, target.status, target.position ?? count);
    }
    final repository = _taskMoveRepository;
    if (repository == null ||
        target.workspaceId.isEmpty ||
        target.projectId.isEmpty ||
        target.status.isEmpty) {
      _actionError(
        'Не удалось определить место назначения. Откройте перемещение заново.',
      );
      return false;
    }
    final operationRevision = _beginTaskOperation();
    final session = authSession.generation;
    emit(
      state.copyWith(
        movingTaskIds: {...state.movingTaskIds, task.id},
        clearActionError: true,
      ),
    );
    try {
      await repository.move(task.id, target);
      if (session != authSession.generation) return false;
      // A board opened earlier must not retain an old copy in either project.
      _cache.clear();
      if (_isCurrentOperation(operationRevision)) {
        emit(
          state.copyWith(
            tasks: state.tasks.where((item) => item.id != task.id).toList(),
            movingTaskIds: _withoutTask(task.id),
          ),
        );
      }
      // If the user switched boards while saving, this cubit also needs a read
      // of its new project. Only the already-updated source can skip that read.
      _publishingTaskChange = _isCurrentOperation(operationRevision);
      try {
        notifyTaskChanges();
      } finally {
        _publishingTaskChange = false;
      }
      return true;
    } catch (error) {
      if (!_isCurrentOperation(operationRevision)) return false;
      emit(state.copyWith(movingTaskIds: _withoutTask(task.id)));
      _actionError(
        error is KanbanException
            ? error.message
            : 'Не удалось переместить задачу. Попробуйте ещё раз.',
      );
      return false;
    } finally {
      if (_isCurrentOperation(operationRevision)) _finishTaskOperation();
    }
  }

  Future<bool> createTask(String status, String title, String priority) async {
    final projectId = state.projectId;
    final revision = _projectRevision;
    final epicIds = state.epicFilterIds.toList(growable: false);
    try {
      final task = await _repository.createTask(
        projectId: projectId,
        title: title,
        status: status,
        priority: priority,
        epicIds: epicIds,
      );
      if (isClosed ||
          revision != _projectRevision ||
          state.projectId != projectId) {
        return true;
      }
      final tasks = <ProjectTaskModel>[...state.tasks, task];
      _cache.write(
        state.projectId,
        KanbanBoardData(columns: state.columns, tasks: tasks),
      );
      emit(state.copyWith(tasks: tasks));
      return true;
    } catch (error) {
      if (!isClosed &&
          revision == _projectRevision &&
          state.projectId == projectId) {
        _actionError(
          error is KanbanException
              ? error.message
              : 'Не удалось создать задачу. Повторите попытку.',
        );
      }
      return false;
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
    int? wip, {
    String? color,
  }) async {
    try {
      final updated = await _repository.updateColumn(
        columnId: column.id,
        name: name,
        wip: wip,
        color: color,
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
    authSession.removeListener(_onSessionChanged);
    assistantTaskChanges.removeListener(_onAiTasksChanged);
    _repository.cancelPendingLoads();
    return super.close();
  }
}
