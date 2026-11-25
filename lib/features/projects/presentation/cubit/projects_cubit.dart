import '../utils/project_move.dart';
import '../utils/project_tree.dart';
import '../../domain/entities/project_model.dart';
import '../../domain/entities/create_project_request.dart';
import '../../domain/entities/project_task_model.dart';
import '../../domain/entities/task_assignee_model.dart';
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/project_repository_impl.dart';
import '../../domain/repositories/project_repository.dart';
import '../../domain/repositories/project_task_repository.dart';
import 'projects_state.dart';

class ProjectsCubit extends Cubit<ProjectsState> {
  ProjectsCubit(this._repository, {ProjectTaskRepository? taskRepository})
    : _taskRepository = taskRepository,
      super(const ProjectsState());

  final ProjectRepository _repository;
  final ProjectTaskRepository? _taskRepository;
  int _loadRevision = 0;
  bool _createInFlight = false;
  bool _moveInFlight = false;
  bool _actionInFlight = false;
  (String, bool)? _deferredLoad;
  final Map<String, String> _selectedProjectIds = <String, String>{};

  Future<String?> moveProject(String id, ProjectMove move) async {
    if (_actionInFlight ||
        _moveInFlight ||
        state.isMoving ||
        state.isLoading ||
        state.isCreating) {
      return 'Дождитесь завершения текущей операции.';
    }
    final tree = buildProjectTree(state.projects);
    final all = [
      for (final root in tree) root,
      for (final root in tree) ...projectDescendants(root),
    ];
    final source = all.where((p) => p.id == id).firstOrNull;
    if (source == null || source.workspaceId != move.workspaceId) {
      return 'Проект больше недоступен.';
    }
    final targetId = move.anchorId ?? move.parentId;
    if (targetId != null) {
      final target = all.where((p) => p.id == targetId).firstOrNull;
      final expected = target == null
          ? null
          : projectMove(
              source,
              target,
              move.anchorId == null ? 'inside' : move.placement,
            );
      if (expected == null || expected != move) {
        return 'Нельзя переместить проект в эту позицию.';
      }
    } else if (move.placement != 'append') {
      return 'Нельзя переместить проект в эту позицию.';
    }
    final workspaceId = state.workspaceId;
    final originalProjects = state.projects;
    _moveInFlight = true;
    _loadRevision++;
    emit(
      state.copyWith(
        isMoving: true,
        projects: applyProjectMove(originalProjects, id, move),
      ),
    );
    try {
      await _repository.moveProject(
        id,
        workspaceId: move.workspaceId,
        parentId: move.parentId,
        anchorId: move.anchorId,
        placement: move.placement,
      );
      if (!isClosed && state.workspaceId == workspaceId) {
        await loadForWorkspace(move.workspaceId, refresh: true);
      }
      return null;
    } catch (_) {
      if (!isClosed && state.workspaceId == workspaceId) {
        emit(state.copyWith(projects: originalProjects));
      }
      return 'Не удалось переместить проект. Проверьте подключение и права доступа.';
    } finally {
      _moveInFlight = false;
      if (!isClosed && state.workspaceId == workspaceId) {
        emit(state.copyWith(isMoving: false));
      }
    }
  }

  Future<String?> setPinned(String id, bool pinned) =>
      _changeProject(id, pinned: pinned);
  Future<String?> archiveProject(String id) => _changeProject(id);

  Future<String?> _changeProject(String id, {bool? pinned}) async {
    if (isClosed ||
        _actionInFlight ||
        _moveInFlight ||
        _createInFlight ||
        state.isLoading) {
      return 'Дождитесь завершения текущей операции.';
    }
    final roots = buildProjectTree(state.projects);
    final all = [
      for (final root in roots) root,
      for (final root in roots) ...projectDescendants(root),
    ];
    final project = all.where((p) => p.id == id).firstOrNull;
    if (project == null) return 'Проект больше недоступен.';
    final workspace = state.workspaceId;
    _actionInFlight = true;
    _loadRevision++;
    emit(state.copyWith(isUpdating: true));
    try {
      if (pinned != null) {
        await _repository.setPinned(id, pinned);
      } else {
        await _repository.archiveProject(id);
      }
      if (isClosed || state.workspaceId != workspace) return null;
      _loadRevision++;
      List<ProjectModel> update(List<ProjectModel> nodes) => [
        for (final node in nodes)
          if (node.id != id || pinned != null)
            node.copyWith(
              isPinned: node.id == id ? pinned : null,
              children: update(node.children),
            ),
      ];
      final projects = _pinnedFirst(update(buildProjectTree(state.projects)));
      final ids = _collectProjectIds(projects).toSet();
      final selected = ids.contains(state.selectedProjectId)
          ? state.selectedProjectId
          : projects.firstOrNull?.id;
      if (workspace != null) {
        if (selected == null) {
          _selectedProjectIds.remove(workspace);
        } else {
          _selectedProjectIds[workspace] = selected;
        }
      }
      emit(
        state.copyWith(
          isLoading: false,
          isProgressLoading: false,
          projects: projects,
          selectedProjectId: selected,
          clearSelectedProject: selected == null,
          projectTaskProgress: {
            for (final entry in state.projectTaskProgress.entries)
              if (ids.contains(entry.key)) entry.key: entry.value,
          },
          projectTaskSummaries: {
            for (final entry in state.projectTaskSummaries.entries)
              if (ids.contains(entry.key)) entry.key: entry.value,
          },
        ),
      );
      if (pinned == null && workspace != null) {
        await loadForWorkspace(workspace, refresh: true);
      }
      return null;
    } on ProjectException catch (error) {
      return error.message;
    } catch (_) {
      return 'Не удалось изменить проект. Попробуйте ещё раз.';
    } finally {
      _actionInFlight = false;
      if (!isClosed && state.workspaceId == workspace) {
        emit(state.copyWith(isUpdating: false));
      }
    }
  }

  void clearWorkspace() {
    _loadRevision++;
    _deferredLoad = null;
    if (!isClosed) {
      emit(
        ProjectsState(
          isCreating: _createInFlight,
          creationRevision: state.creationRevision,
        ),
      );
    }
  }

  Future<void> loadForWorkspace(
    String workspaceId, {
    bool refresh = false,
  }) async {
    if (isClosed || workspaceId.isEmpty) return;
    if (_createInFlight) {
      _deferredLoad = (workspaceId, refresh);
      if (state.workspaceId != workspaceId) {
        emit(
          ProjectsState(
            workspaceId: workspaceId,
            isLoading: true,
            isCreating: true,
            creationRevision: state.creationRevision,
          ),
        );
      }
      return;
    }
    final revision = ++_loadRevision;
    final previous = state;
    final keepContent = refresh && previous.workspaceId == workspaceId;
    emit(
      keepContent
          ? previous.copyWith(
              isLoading: true,
              isProgressLoading: false,
              clearError: true,
              clearProgressError: true,
            )
          : ProjectsState(
              workspaceId: workspaceId,
              isLoading: true,
              isCreating: state.isCreating,
              creationRevision: state.creationRevision,
            ),
    );

    try {
      final allProjects = await _repository.getProjects();
      if (revision != _loadRevision || isClosed) return;
      final filtered = allProjects
          .where((project) => project.workspaceId == workspaceId)
          .toList(growable: false);
      final projects = _pinnedFirst(filtered);
      final taskProjectIds = _collectProjectIds(projects);
      var summaries = const <String, ProjectTaskSummary>{};
      if (_taskRepository != null && taskProjectIds.isNotEmpty) {
        // Publish the project snapshot and its calculated progress together.
        // During refresh the previous complete snapshot remains visible.
        emit(state.copyWith(isProgressLoading: true));
        try {
          final tasks = await _taskRepository.getTasksForProjectIds(
            taskProjectIds,
          );
          if (revision != _loadRevision || isClosed) return;
          summaries = _calculateSummaries(projects, tasks);
        } catch (_) {
          if (revision != _loadRevision || isClosed) return;
          const message =
              'Не удалось загрузить прогресс проектов. Попробуйте ещё раз.';
          emit(
            state.copyWith(
              isLoading: false,
              isProgressLoading: false,
              errorMessage: message,
              progressErrorMessage: message,
            ),
          );
          return;
        }
      }
      if (revision != _loadRevision || isClosed) return;
      final savedProjectId = _selectedProjectIds[workspaceId];
      final selectedProjectId = taskProjectIds.contains(savedProjectId)
          ? savedProjectId
          : projects.firstOrNull?.id;
      if (selectedProjectId != null) {
        _selectedProjectIds[workspaceId] = selectedProjectId;
      } else {
        _selectedProjectIds.remove(workspaceId);
      }
      emit(
        ProjectsState(
          workspaceId: workspaceId,
          projects: projects,
          selectedProjectId: selectedProjectId,
          creationRevision: state.creationRevision,
          creationError: state.creationError,
          projectTaskProgress: {
            for (final entry in summaries.entries)
              entry.key: entry.value.total == 0
                  ? 0
                  : ((entry.value.completed / entry.value.total) * 100).round(),
          },
          projectTaskSummaries: summaries,
        ),
      );
    } on ProjectException catch (error) {
      if (revision != _loadRevision || isClosed) return;
      emit(
        keepContent
            ? state.copyWith(isLoading: false, errorMessage: error.message)
            : ProjectsState(
                workspaceId: workspaceId,
                errorMessage: error.message,
                creationRevision: state.creationRevision,
                creationError: state.creationError,
              ),
      );
    } catch (_) {
      if (revision != _loadRevision || isClosed) return;
      emit(
        keepContent
            ? state.copyWith(
                isLoading: false,
                errorMessage: 'Не удалось обновить проекты.',
              )
            : ProjectsState(
                workspaceId: workspaceId,
                errorMessage: 'Не удалось загрузить проекты.',
                creationRevision: state.creationRevision,
                creationError: state.creationError,
              ),
      );
    }
  }

  void selectProject(String projectId) {
    if (!_collectProjectIds(state.projects).contains(projectId) ||
        state.selectedProjectId == projectId) {
      return;
    }

    final workspaceId = state.workspaceId;
    if (workspaceId != null) _selectedProjectIds[workspaceId] = projectId;
    emit(state.copyWith(selectedProjectId: projectId));
  }

  Future<bool> createProject(CreateProjectRequest request) async {
    if (isClosed || _createInFlight || _moveInFlight || _actionInFlight) {
      return false;
    }
    final validationMessage = _validate(request);
    if (validationMessage != null) {
      emit(state.copyWith(creationError: validationMessage, clearError: true));
      return false;
    }

    _createInFlight = true;
    if ((state.isLoading || state.isProgressLoading) &&
        state.workspaceId != null) {
      _deferredLoad = (state.workspaceId!, true);
    }
    // Reads started before this mutation must not replace the created project.
    _loadRevision++;
    emit(
      state.copyWith(
        isCreating: true,
        isLoading: false,
        isProgressLoading: false,
        clearCreationError: true,
        clearError: true,
      ),
    );
    try {
      final created = await _repository.createProject(request);
      if (isClosed) return false;
      if (state.workspaceId != request.workspaceId) {
        emit(
          state.copyWith(
            isCreating: false,
            clearCreationError: true,
            creationRevision: state.creationRevision + 1,
          ),
        );
        return true;
      }
      final selectedProjectId = state.selectedProjectId ?? created.id;
      final workspaceId = state.workspaceId;
      if (workspaceId != null && selectedProjectId.isNotEmpty) {
        _selectedProjectIds[workspaceId] = selectedProjectId;
      }
      emit(
        state.copyWith(
          projects: _pinnedFirst(<ProjectModel>[
            ...state.projects.where((project) => project.id != created.id),
            created,
          ]),
          selectedProjectId: selectedProjectId,
          isCreating: false,
          clearCreationError: true,
          creationRevision: state.creationRevision + 1,
        ),
      );
      return true;
    } on ProjectException catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isCreating: false,
            creationError: state.workspaceId == request.workspaceId
                ? error.message
                : null,
          ),
        );
      }
      return false;
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isCreating: false,
            creationError: state.workspaceId == request.workspaceId
                ? 'Не удалось создать проект.'
                : null,
          ),
        );
      }
      return false;
    } finally {
      _createInFlight = false;
      final deferred = _deferredLoad;
      _deferredLoad = null;
      if (!isClosed) {
        if (state.isCreating) emit(state.copyWith(isCreating: false));
        if (deferred != null && state.workspaceId == deferred.$1) {
          unawaited(loadForWorkspace(deferred.$1, refresh: deferred.$2));
        }
      }
    }
  }

  String? _validate(CreateProjectRequest request) {
    if (request.workspaceId.trim().isEmpty) return 'Выберите workspace.';
    if (request.code.trim().isEmpty) return 'Введите код проекта.';
    if (request.name.trim().isEmpty) return 'Введите название проекта.';
    if (request.end != null &&
        request.start != null &&
        request.end!.isBefore(request.start!)) {
      return 'Дата окончания не может быть раньше даты начала.';
    }
    if (request.progress < 0 || request.progress > 100) {
      return 'Прогресс должен быть от 0 до 100.';
    }
    return null;
  }

  List<ProjectModel> _pinnedFirst(List<ProjectModel> projects) {
    final pinned = <ProjectModel>[];
    final regular = <ProjectModel>[];
    for (final project in projects) {
      (project.isPinned ? pinned : regular).add(project);
    }
    return <ProjectModel>[...pinned, ...regular];
  }

  List<String> _collectProjectIds(List<ProjectModel> projects) {
    final ids = <String>{};

    void visit(ProjectModel project) {
      if (project.id.isNotEmpty) ids.add(project.id);
      for (final child in project.children) {
        visit(child);
      }
    }

    for (final project in projects) {
      visit(project);
    }
    return ids.toList(growable: false);
  }

  Map<String, ProjectTaskSummary> _calculateSummaries(
    List<ProjectModel> projects,
    List<ProjectTaskModel> tasks,
  ) {
    return <String, ProjectTaskSummary>{
      for (final project in projects)
        project.id: _summaryForProject(project, tasks),
    };
  }

  ProjectTaskSummary _summaryForProject(
    ProjectModel project,
    List<ProjectTaskModel> tasks,
  ) {
    final scopeIds = _collectProjectIds(<ProjectModel>[project]).toSet();
    final projectTasks = tasks
        .where((task) => scopeIds.contains(task.projectId))
        .toList(growable: false);
    final assigneesById = <String, TaskAssigneeModel>{};
    for (final task in projectTasks) {
      for (final assignee in task.assignees) {
        if (assignee.userId.isNotEmpty) {
          assigneesById[assignee.userId] = assignee;
        }
      }
    }
    return ProjectTaskSummary(
      completed: projectTasks.where((task) => task.isDone).length,
      total: projectTasks.length,
      assignees: assigneesById.values.toList(growable: false),
    );
  }
}
