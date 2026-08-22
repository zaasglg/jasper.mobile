import 'package:equatable/equatable.dart';

import '../../data/models/project_model.dart';

class ProjectsState extends Equatable {
  const ProjectsState({
    this.workspaceId,
    this.projects = const <ProjectModel>[],
    this.isLoading = false,
    this.isCreating = false,
    this.errorMessage,
    this.creationError,
    this.creationRevision = 0,
  });

  final String? workspaceId;
  final List<ProjectModel> projects;
  final bool isLoading;
  final bool isCreating;
  final String? errorMessage;
  final String? creationError;
  final int creationRevision;

  ProjectsState copyWith({
    String? workspaceId,
    List<ProjectModel>? projects,
    bool? isLoading,
    bool? isCreating,
    String? errorMessage,
    bool clearError = false,
    String? creationError,
    bool clearCreationError = false,
    int? creationRevision,
  }) {
    return ProjectsState(
      workspaceId: workspaceId ?? this.workspaceId,
      projects: projects ?? this.projects,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      creationError: clearCreationError
          ? null
          : creationError ?? this.creationError,
      creationRevision: creationRevision ?? this.creationRevision,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    workspaceId,
    projects,
    isLoading,
    isCreating,
    errorMessage,
    creationError,
    creationRevision,
  ];
}
