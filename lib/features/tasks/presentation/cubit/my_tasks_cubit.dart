import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../projects/data/models/project_model.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../data/models/kanban_column_model.dart';
import '../../data/repositories/my_tasks_repository_impl.dart';
import '../../domain/entities/task_extra_field.dart';
import '../../domain/repositories/my_task_fields_storage.dart';
import '../../domain/repositories/my_tasks_repository.dart';
import 'my_tasks_state.dart';

class MyTasksCubit extends Cubit<MyTasksState> {
  MyTasksCubit({
    required MyTasksRepository repository,
    required MyTaskFieldsStorage fieldsStorage,
  }) : _repository = repository,
       _fieldsStorage = fieldsStorage,
       super(const MyTasksState());

  final MyTasksRepository _repository;
  final MyTaskFieldsStorage _fieldsStorage;
  String _userId = '';
  String _configurationKey = '';
  int _loadRevision = 0;

  Future<void> initializeFields() async {
    try {
      final fields = await _fieldsStorage.read();
      if (!isClosed) emit(state.copyWith(visibleFields: fields));
    } catch (_) {
      // The defaults remain enabled when local storage is unavailable.
    }
  }

  Future<void> configure({
    required String userId,
    required List<ProjectModel> projects,
  }) async {
    if (userId.isEmpty) return;
    final configurationKey = '$userId:${_allProjectIds(projects).join(',')}';
    if (_configurationKey == configurationKey) return;
    _configurationKey = configurationKey;
    _userId = userId;

    final availableIds = projects.map((project) => project.id).toSet();
    final selectedIds = state.selectedProjectIds.intersection(availableIds);
    emit(
      state.copyWith(
        projects: List<ProjectModel>.unmodifiable(projects),
        tasks: const <ProjectTaskModel>[],
        columnsByProjectId: const <String, List<KanbanColumnModel>>{},
        selectedProjectIds: selectedIds,
        selectedScopeProjectIds: _scopeIds(projects, selectedIds),
      ),
    );
    await refresh(showLoading: true);
  }

  Future<void> selectProjects(Set<String> projectIds) async {
    final availableIds = state.projects.map((project) => project.id).toSet();
    final selectedIds = projectIds.intersection(availableIds);
    if (_sameSet(selectedIds, state.selectedProjectIds)) return;
    emit(
      state.copyWith(
        selectedProjectIds: selectedIds,
        selectedScopeProjectIds: _scopeIds(state.projects, selectedIds),
        tasks: const <ProjectTaskModel>[],
        columnsByProjectId: const <String, List<KanbanColumnModel>>{},
      ),
    );
    await refresh(showLoading: true);
  }

  Future<void> refresh({bool showLoading = false}) async {
    if (_userId.isEmpty) return;
    final revision = ++_loadRevision;
    if (showLoading || state.tasks.isEmpty) {
      emit(
        state.copyWith(
          status: MyTasksStatus.loading,
          clearError: true,
          clearActionError: true,
        ),
      );
    }

    try {
      final tasks = await _repository.getTasks(
        assigneeId: _userId,
        projectIds: state.selectedScopeProjectIds.toList(growable: false),
      );
      if (revision != _loadRevision || isClosed) return;
      final filteredTasks = state.selectedScopeProjectIds.isEmpty
          ? tasks
          : tasks
                .where(
                  (task) =>
                      state.selectedScopeProjectIds.contains(task.projectId),
                )
                .toList(growable: false);
      final projectIds = filteredTasks
          .map((task) => task.projectId)
          .where((id) => id.isNotEmpty)
          .toSet();
      final entries = await Future.wait(
        projectIds.map((projectId) async {
          final columns = await _repository.getKanbanColumns(projectId);
          return MapEntry(projectId, columns);
        }),
      );
      if (revision != _loadRevision || isClosed) return;
      emit(
        state.copyWith(
          status: MyTasksStatus.success,
          tasks: List<ProjectTaskModel>.unmodifiable(filteredTasks),
          columnsByProjectId: Map<String, List<KanbanColumnModel>>.fromEntries(
            entries,
          ),
          clearError: true,
          clearActionError: true,
        ),
      );
    } on MyTasksException catch (error) {
      if (revision != _loadRevision || isClosed) return;
      _emitLoadFailure(error.message);
    } catch (_) {
      if (revision != _loadRevision || isClosed) return;
      _emitLoadFailure('Не удалось загрузить задачи.');
    }
  }

  void toggleSort() {
    emit(state.copyWith(sortAscending: !state.sortAscending));
  }

  Future<void> toggleField(TaskExtraField field) async {
    final fields = Set<TaskExtraField>.from(state.visibleFields);
    fields.contains(field) ? fields.remove(field) : fields.add(field);
    emit(state.copyWith(visibleFields: fields));
    try {
      await _fieldsStorage.save(fields);
    } catch (_) {
      // A storage error must not block changing the current view.
    }
  }

  Future<void> toggleTask(ProjectTaskModel task) async {
    if (state.updatingTaskIds.contains(task.id)) return;
    final oldTasks = state.tasks;
    final targetProgress = task.isDone ? 0 : 100;
    final optimisticTask = task.copyWith(
      progress: targetProgress.toDouble(),
      status: targetProgress == 0 && task.status.toUpperCase() == 'DONE'
          ? 'TODO'
          : task.status,
    );
    emit(
      state.copyWith(
        tasks: oldTasks
            .map((item) => item.id == task.id ? optimisticTask : item)
            .toList(growable: false),
        updatingTaskIds: <String>{...state.updatingTaskIds, task.id},
        clearActionError: true,
      ),
    );

    try {
      await _repository.updateProgress(task.id, targetProgress);
      if (isClosed) return;
      final updatingIds = Set<String>.from(state.updatingTaskIds)
        ..remove(task.id);
      emit(state.copyWith(updatingTaskIds: updatingIds));
    } on MyTasksException catch (error) {
      if (isClosed) return;
      _rollbackTask(task, error.message);
    } catch (_) {
      if (isClosed) return;
      _rollbackTask(task, 'Не удалось обновить задачу.');
    }
  }

  void _rollbackTask(ProjectTaskModel oldTask, String message) {
    final updatingIds = Set<String>.from(state.updatingTaskIds)
      ..remove(oldTask.id);
    emit(
      state.copyWith(
        tasks: state.tasks
            .map((item) => item.id == oldTask.id ? oldTask : item)
            .toList(growable: false),
        updatingTaskIds: updatingIds,
        actionErrorMessage: message,
        actionRevision: state.actionRevision + 1,
      ),
    );
  }

  void _emitLoadFailure(String message) {
    emit(
      state.copyWith(
        status: state.tasks.isEmpty
            ? MyTasksStatus.failure
            : MyTasksStatus.success,
        errorMessage: state.tasks.isEmpty ? message : null,
        actionErrorMessage: state.tasks.isEmpty ? null : message,
        actionRevision: state.tasks.isEmpty
            ? state.actionRevision
            : state.actionRevision + 1,
      ),
    );
  }

  Set<String> _scopeIds(List<ProjectModel> projects, Set<String> selectedIds) {
    if (selectedIds.isEmpty) return const <String>{};
    final result = <String>{};

    void visit(ProjectModel project) {
      if (project.id.isNotEmpty) result.add(project.id);
      for (final child in project.children) {
        visit(child);
      }
    }

    for (final project in projects) {
      if (selectedIds.contains(project.id)) visit(project);
    }
    return result;
  }

  List<String> _allProjectIds(List<ProjectModel> projects) {
    final result = <String>[];

    void visit(ProjectModel project) {
      if (project.id.isNotEmpty) result.add(project.id);
      for (final child in project.children) {
        visit(child);
      }
    }

    for (final project in projects) {
      visit(project);
    }
    return result;
  }

  bool _sameSet<T>(Set<T> left, Set<T> right) {
    return left.length == right.length && left.containsAll(right);
  }
}
