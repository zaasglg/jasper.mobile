import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/create_project_request.dart';
import '../../data/models/project_model.dart';
import '../../data/repositories/project_repository_impl.dart';
import '../../domain/repositories/project_repository.dart';
import 'projects_state.dart';

class ProjectsCubit extends Cubit<ProjectsState> {
  ProjectsCubit(this._repository) : super(const ProjectsState());

  final ProjectRepository _repository;
  int _loadRevision = 0;

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
      emit(
        ProjectsState(
          workspaceId: workspaceId,
          projects: _pinnedFirst(filtered),
        ),
      );
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
      emit(
        state.copyWith(
          projects: _pinnedFirst(<ProjectModel>[...state.projects, created]),
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
}
