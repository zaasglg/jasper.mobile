import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/workspace_selection_storage.dart';
import '../../../projects/data/models/project_model.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../data/models/task_creation_models.dart';
import '../../data/models/task_detail_model.dart';
import '../../domain/repositories/task_creation_repository.dart';

class TaskCreationState extends Equatable {
  const TaskCreationState({
    this.catalog,
    this.projects = const [],
    this.options = const TaskCreationOptions(),
    this.draft = const TaskCreationRequest(
      workspaceId: '',
      projectId: '',
      title: '',
      status: '',
    ),
    this.loading = true,
    this.loadingProjects = false,
    this.loadingOptions = false,
    this.submitting = false,
    this.error,
    this.result,
  });
  final TaskCreationCatalog? catalog;
  final List<ProjectModel> projects;
  final TaskCreationOptions options;
  final TaskCreationRequest draft;
  final bool loading, loadingProjects, loadingOptions, submitting;
  final String? error;
  final TaskCreationResult? result;
  List<ProjectTaskModel> get siblings =>
      options.tasks.where((e) => e.status == draft.status).toList();
  bool get canSubmit =>
      !loading &&
      !loadingProjects &&
      !loadingOptions &&
      !submitting &&
      result == null &&
      draft.title.trim().isNotEmpty &&
      projects.any((e) => e.id == draft.projectId) &&
      options.columns.any((e) => e.statusMap == draft.status);
  TaskCreationState copyWith({
    TaskCreationCatalog? catalog,
    List<ProjectModel>? projects,
    TaskCreationOptions? options,
    TaskCreationRequest? draft,
    bool? loading,
    bool? loadingProjects,
    bool? loadingOptions,
    bool? submitting,
    String? error,
    TaskCreationResult? result,
  }) => TaskCreationState(
    catalog: catalog ?? this.catalog,
    projects: projects ?? this.projects,
    options: options ?? this.options,
    draft: draft ?? this.draft,
    loading: loading ?? this.loading,
    loadingProjects: loadingProjects ?? this.loadingProjects,
    loadingOptions: loadingOptions ?? this.loadingOptions,
    submitting: submitting ?? this.submitting,
    error: error,
    result: result ?? this.result,
  );
  @override
  List<Object?> get props => [
    catalog,
    projects,
    options,
    draft,
    loading,
    loadingProjects,
    loadingOptions,
    submitting,
    error,
    result,
  ];
}

class TaskCreationCubit extends Cubit<TaskCreationState> {
  TaskCreationCubit(this.repository, {this.workspaceStorage})
    : super(const TaskCreationState());
  final TaskCreationRepository repository;
  final WorkspaceSelectionStorage? workspaceStorage;
  int _revision = 0;
  static String message(Object error) {
    if (error is TaskCreationException) return error.message;
    if (error is DioException) {
      if (error.response?.statusCode == 403) {
        return 'Недостаточно прав для создания задачи в этом проекте';
      }
      if (error.response?.statusCode == 413) {
        return 'Вложения слишком большие. Уменьшите их общий размер';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Нет соединения с сервером. Повторите попытку';
      }
    }
    return 'Не удалось выполнить действие. Повторите попытку';
  }

  Future<void> initialize({String? workspaceId}) async {
    final revision = ++_revision;
    emit(state.copyWith(loading: true));
    try {
      final catalog = await repository.catalog();
      final selected = workspaceId?.isNotEmpty == true
          ? workspaceId
          : await workspaceStorage?.read();
      if (isClosed || revision != _revision) return;
      final id = catalog.workspaces.any((e) => e.id == selected)
          ? selected!
          : catalog.workspaces.firstOrNull?.id ?? '';
      emit(state.copyWith(catalog: catalog, loading: false));
      if (id.isNotEmpty) await selectWorkspace(id);
    } catch (error) {
      if (!isClosed && revision == _revision) {
        emit(state.copyWith(loading: false, error: message(error)));
      }
    }
  }

  Future<void> selectWorkspace(String id) async {
    if (state.submitting ||
        state.catalog?.workspaces.any((e) => e.id == id) != true) {
      return;
    }
    final revision = ++_revision;
    emit(
      state.copyWith(
        draft: state.draft.copyWith(
          workspaceId: id,
          projectId: '',
          status: '',
          epicIds: [],
          assigneeIds: [],
          position: 1,
        ),
        projects: [],
        options: const TaskCreationOptions(),
        loadingProjects: true,
        loadingOptions: false,
      ),
    );
    try {
      final results = await Future.wait<Object>([
        repository.projects(id),
        repository.members(id),
      ]);
      if (isClosed || revision != _revision) return;
      final projects = results[0] as List<ProjectModel>;
      final members = results[1] as List<TaskAssigneeModel>;
      emit(
        state.copyWith(
          projects: projects,
          options: state.options.copyWith(members: members),
          loadingProjects: false,
        ),
      );
      if (projects.length == 1) await selectProject(projects.single.id);
    } catch (error) {
      if (!isClosed && revision == _revision) {
        emit(state.copyWith(loadingProjects: false, error: message(error)));
      }
    }
  }

  Future<void> selectProject(String id) async {
    if (state.submitting || !state.projects.any((e) => e.id == id)) return;
    final revision = ++_revision;
    final workspace = state.draft.workspaceId;
    emit(
      state.copyWith(
        draft: state.draft.copyWith(
          projectId: id,
          status: '',
          epicIds: [],
          assigneeIds: [],
          position: 1,
        ),
        options: const TaskCreationOptions(),
        loadingOptions: true,
      ),
    );
    try {
      var options = await repository.options(workspace, id);
      if (isClosed || revision != _revision) return;
      final user = state.catalog?.user;
      if (user != null && !options.members.any((e) => e.userId == user.id)) {
        options = options.copyWith(
          members: [
            ...options.members,
            TaskAssigneeModel(
              userId: user.id,
              name: user.name,
              avatarUrl: user.avatarUrl,
            ),
          ],
        );
      }
      final status = options.columns.firstOrNull?.statusMap ?? '';
      emit(
        state.copyWith(
          options: options,
          loadingOptions: false,
          draft: state.draft.copyWith(
            status: status,
            position: options.tasks.where((e) => e.status == status).length + 1,
          ),
        ),
      );
    } catch (error) {
      if (!isClosed && revision == _revision) {
        emit(state.copyWith(loadingOptions: false, error: message(error)));
      }
    }
  }

  void change(TaskCreationRequest draft) {
    if (!state.submitting && state.result == null) {
      emit(state.copyWith(draft: draft));
    }
  }

  void selectColumn(String status) {
    if (!state.options.columns.any((e) => e.statusMap == status)) return;
    change(
      state.draft.copyWith(
        status: status,
        position:
            state.options.tasks.where((e) => e.status == status).length + 1,
      ),
    );
  }

  void addFiles(List<TaskFileModel> files) {
    if (state.submitting) return;
    final all = [...state.draft.files, ...files];
    if (all.fold<int>(0, (value, file) => value + file.size) >
        35 * 1024 * 1024) {
      emit(
        state.copyWith(
          error: 'Общий размер вложений должен быть не больше 35 МБ',
        ),
      );
      return;
    }
    change(state.draft.copyWith(files: all));
  }

  Future<TaskCreationResult?> submit() async {
    if (!state.canSubmit) {
      if (!state.submitting) {
        emit(
          state.copyWith(error: 'Введите название и выберите проект и колонку'),
        );
      }
      return null;
    }
    final draft = state.draft;
    final siblings = state.siblings;
    emit(state.copyWith(submitting: true));
    try {
      final result = await repository.create(draft, siblings);
      if (isClosed) return result;
      emit(state.copyWith(submitting: false, result: result));
      return result;
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(submitting: false, error: message(error)));
      }
      return null;
    }
  }

  @override
  Future<void> close() {
    _revision++;
    return super.close();
  }
}
