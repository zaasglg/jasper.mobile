import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/create_project_request.dart';
import '../../data/models/project_model.dart';
import '../../data/models/project_task_model.dart';
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
  final Map<String, String> _selectedProjectIds = <String, String>{};

  Future<void> loadForWorkspace(String workspaceId) async {
    if (workspaceId.isEmpty) return;
    final revision = ++_loadRevision;
    emit(
      ProjectsState(
        workspaceId: workspaceId,
        isLoading: true,
        isCreating: state.isCreating,
      ),
    );

    try {
      final allProjects = await _repository.getProjects();
      if (revision != _loadRevision || isClosed) return;
      final filtered = allProjects
          .where((project) => project.workspaceId == workspaceId)
          .toList(growable: false);
      final projects = _pinnedFirst(filtered);
      final savedProjectId = _selectedProjectIds[workspaceId];
      final selectedProjectId =
          projects.any((project) => project.id == savedProjectId)
          ? savedProjectId
          : projects.firstOrNull?.id;
      if (selectedProjectId != null) {
        _selectedProjectIds[workspaceId] = selectedProjectId;
      } else {
        _selectedProjectIds.remove(workspaceId);
      }

      final progressProjects = projects;
      final taskProjectIds = _collectProjectIds(progressProjects);
      emit(
        ProjectsState(
          workspaceId: workspaceId,
          projects: projects,
          selectedProjectId: selectedProjectId,
          isProgressLoading:
              _taskRepository != null && taskProjectIds.isNotEmpty,
        ),
      );

      if (_taskRepository == null || taskProjectIds.isEmpty) return;
      try {
        final tasks = await _taskRepository.getTasksForProjectIds(
          taskProjectIds,
        );
        if (revision != _loadRevision || isClosed) return;
        final summaries = _calculateSummaries(progressProjects, tasks);
        emit(
          state.copyWith(
            projectTaskProgress: <String, int>{
              for (final entry in summaries.entries)
                entry.key: entry.value.total == 0
                    ? 0
                    : ((entry.value.completed / entry.value.total) * 100)
                          .round(),
            },
            projectTaskSummaries: summaries,
            isProgressLoading: false,
            clearProgressError: true,
          ),
        );
      } on ProjectException catch (error) {
        if (revision != _loadRevision || isClosed) return;
        emit(
          state.copyWith(
            isProgressLoading: false,
            progressErrorMessage: error.message,
          ),
        );
      } catch (_) {
        if (revision != _loadRevision || isClosed) return;
        emit(
          state.copyWith(
            isProgressLoading: false,
            progressErrorMessage: 'Не удалось рассчитать прогресс проектов.',
          ),
        );
      }
    } on ProjectException catch (error) {
      if (revision != _loadRevision || isClosed) return;
      emit(
        ProjectsState(workspaceId: workspaceId, errorMessage: error.message),
      );
    } catch (_) {
      if (revision != _loadRevision || isClosed) return;
      emit(
        ProjectsState(
          workspaceId: workspaceId,
          errorMessage: 'Не удалось загрузить проекты.',
        ),
      );
    }
  }

  void selectProject(String projectId) {
    if (!state.projects.any((project) => project.id == projectId) ||
        state.selectedProjectId == projectId) {
      return;
    }

    final workspaceId = state.workspaceId;
    if (workspaceId != null) _selectedProjectIds[workspaceId] = projectId;
    emit(state.copyWith(selectedProjectId: projectId));
  }

  Future<bool> createProject(CreateProjectRequest request) async {
    if (state.isCreating) return false;
    final validationMessage = _validate(request);
    if (validationMessage != null) {
      emit(state.copyWith(creationError: validationMessage, clearError: true));
      return false;
    }

    emit(
      state.copyWith(
        isCreating: true,
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
          projects: _pinnedFirst(<ProjectModel>[...state.projects, created]),
          selectedProjectId: selectedProjectId,
          isCreating: false,
          clearCreationError: true,
          creationRevision: state.creationRevision + 1,
        ),
      );
      return true;
    } on ProjectException catch (error) {
      if (!isClosed) {
        emit(state.copyWith(isCreating: false, creationError: error.message));
      }
      return false;
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isCreating: false,
            creationError: 'Не удалось создать проект.',
          ),
        );
      }
      return false;
    }
  }

  String? _validate(CreateProjectRequest request) {
    if (request.workspaceId.trim().isEmpty) return 'Выберите workspace.';
    if (request.code.trim().isEmpty) return 'Введите код проекта.';
    if (request.name.trim().isEmpty) return 'Введите название проекта.';
    if (request.end.isBefore(request.start)) {
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
