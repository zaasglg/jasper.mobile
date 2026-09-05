import 'package:equatable/equatable.dart';

import '../../data/models/project_model.dart';
import '../../data/models/project_task_model.dart';

class ProjectTaskSummary extends Equatable {
  const ProjectTaskSummary({
    required this.completed,
    required this.total,
    this.assignees = const <TaskAssigneeModel>[],
  });

  final int completed;
  final int total;
  final List<TaskAssigneeModel> assignees;

  @override
  List<Object?> get props => <Object?>[completed, total, assignees];
}

class ProjectsState extends Equatable {
  const ProjectsState({
    this.workspaceId,
    this.projects = const <ProjectModel>[],
    this.selectedProjectId,
    this.isLoading = false,
    this.isCreating = false,
    this.errorMessage,
    this.creationError,
    this.creationRevision = 0,
    this.projectTaskProgress = const <String, int>{},
    this.projectTaskSummaries = const <String, ProjectTaskSummary>{},
    this.isProgressLoading = false,
    this.progressErrorMessage,
  });

  final String? workspaceId;
  final List<ProjectModel> projects;
  final String? selectedProjectId;
  final bool isLoading;
  final bool isCreating;
  final String? errorMessage;
  final String? creationError;
  final int creationRevision;
  final Map<String, int> projectTaskProgress;
  final Map<String, ProjectTaskSummary> projectTaskSummaries;
  final bool isProgressLoading;
  final String? progressErrorMessage;

  ProjectsState copyWith({
    String? workspaceId,
    List<ProjectModel>? projects,
    String? selectedProjectId,
    bool? isLoading,
    bool? isCreating,
    String? errorMessage,
    bool clearError = false,
    String? creationError,
    bool clearCreationError = false,
    int? creationRevision,
    Map<String, int>? projectTaskProgress,
    Map<String, ProjectTaskSummary>? projectTaskSummaries,
    bool? isProgressLoading,
    String? progressErrorMessage,
    bool clearProgressError = false,
  }) {
    return ProjectsState(
      workspaceId: workspaceId ?? this.workspaceId,
      projects: projects ?? this.projects,
      selectedProjectId: selectedProjectId ?? this.selectedProjectId,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      creationError: clearCreationError
          ? null
          : creationError ?? this.creationError,
      creationRevision: creationRevision ?? this.creationRevision,
      projectTaskProgress: projectTaskProgress ?? this.projectTaskProgress,
      projectTaskSummaries: projectTaskSummaries ?? this.projectTaskSummaries,
      isProgressLoading: isProgressLoading ?? this.isProgressLoading,
      progressErrorMessage: clearProgressError
          ? null
          : progressErrorMessage ?? this.progressErrorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    workspaceId,
    projects,
    selectedProjectId,
    isLoading,
    isCreating,
    errorMessage,
    creationError,
    creationRevision,
    projectTaskProgress,
    projectTaskSummaries,
    isProgressLoading,
    progressErrorMessage,
  ];
}
