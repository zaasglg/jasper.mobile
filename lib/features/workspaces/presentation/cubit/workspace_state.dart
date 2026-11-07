import 'package:equatable/equatable.dart';

import '../../data/models/workspace_model.dart';

sealed class WorkspaceState extends Equatable {
  const WorkspaceState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class WorkspaceInitial extends WorkspaceState {
  const WorkspaceInitial();
}

final class WorkspaceLoading extends WorkspaceState {
  const WorkspaceLoading();
}

final class WorkspaceLoaded extends WorkspaceState {
  const WorkspaceLoaded({
    required this.workspaces,
    required this.selected,
    this.isCreating = false,
    this.creationError,
    this.isRefreshing = false,
    this.refreshError,
    this.archivedWorkspaces = const [],
    this.isLoadingArchived = false,
    this.hasLoadedArchived = false,
    this.archivedError,
  });

  final List<WorkspaceModel> workspaces;
  final WorkspaceModel? selected;
  final bool isCreating;
  final String? creationError;
  final bool isRefreshing;
  final String? refreshError;
  final List<WorkspaceModel> archivedWorkspaces;
  final bool isLoadingArchived, hasLoadedArchived;
  final String? archivedError;

  WorkspaceLoaded copyWith({
    List<WorkspaceModel>? workspaces,
    Object? selected = _unset,
    bool? isCreating,
    Object? creationError = _unset,
    bool? isRefreshing,
    Object? refreshError = _unset,
    List<WorkspaceModel>? archivedWorkspaces,
    bool? isLoadingArchived,
    bool? hasLoadedArchived,
    Object? archivedError = _unset,
  }) {
    return WorkspaceLoaded(
      workspaces: workspaces ?? this.workspaces,
      selected: identical(selected, _unset)
          ? this.selected
          : selected as WorkspaceModel?,
      isCreating: isCreating ?? this.isCreating,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshError: identical(refreshError, _unset)
          ? this.refreshError
          : refreshError as String?,
      archivedWorkspaces: archivedWorkspaces ?? this.archivedWorkspaces,
      isLoadingArchived: isLoadingArchived ?? this.isLoadingArchived,
      hasLoadedArchived: hasLoadedArchived ?? this.hasLoadedArchived,
      archivedError: identical(archivedError, _unset)
          ? this.archivedError
          : archivedError as String?,
      creationError: identical(creationError, _unset)
          ? this.creationError
          : creationError as String?,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    workspaces,
    selected,
    isCreating,
    creationError,
    isRefreshing,
    refreshError,
    archivedWorkspaces,
    isLoadingArchived,
    hasLoadedArchived,
    archivedError,
  ];
}

const Object _unset = Object();

final class WorkspaceFailure extends WorkspaceState {
  const WorkspaceFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
