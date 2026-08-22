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
  });

  final List<WorkspaceModel> workspaces;
  final WorkspaceModel? selected;
  final bool isCreating;
  final String? creationError;

  WorkspaceLoaded copyWith({
    List<WorkspaceModel>? workspaces,
    WorkspaceModel? selected,
    bool? isCreating,
    Object? creationError = _unset,
  }) {
    return WorkspaceLoaded(
      workspaces: workspaces ?? this.workspaces,
      selected: selected ?? this.selected,
      isCreating: isCreating ?? this.isCreating,
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
  ];
}

const Object _unset = Object();

final class WorkspaceFailure extends WorkspaceState {
  const WorkspaceFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
