import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/workspace_selection_storage.dart';
import '../../data/models/create_workspace_request.dart';
import '../../data/models/workspace_model.dart';
import '../../data/repositories/workspace_repository_impl.dart';
import '../../domain/repositories/workspace_repository.dart';
import 'workspace_state.dart';

class WorkspaceCubit extends Cubit<WorkspaceState> {
  WorkspaceCubit({
    required WorkspaceRepository repository,
    required WorkspaceSelectionStorage selectionStorage,
  }) : _repository = repository,
       _selectionStorage = selectionStorage,
       super(const WorkspaceInitial());

  final WorkspaceRepository _repository;
  final WorkspaceSelectionStorage _selectionStorage;

  Future<void> load({bool force = false}) async {
    if (!force && (state is WorkspaceLoading || state is WorkspaceLoaded)) {
      return;
    }

    emit(const WorkspaceLoading());
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getWorkspaces(),
        _selectionStorage.read(),
      ]);
      if (isClosed) return;
      final workspaces = results[0] as List<WorkspaceModel>;
      final savedId = results[1] as String?;
      final selected = _findSelected(workspaces, savedId);

      if (selected != null && selected.id != savedId) {
        await _selectionStorage.save(selected.id);
      }
      if (isClosed) return;
      emit(WorkspaceLoaded(workspaces: workspaces, selected: selected));
    } on WorkspaceException catch (error) {
      if (!isClosed) emit(WorkspaceFailure(error.message));
    } catch (_) {
      if (!isClosed) {
        emit(const WorkspaceFailure('Не удалось загрузить workspace.'));
      }
    }
  }

  Future<void> select(WorkspaceModel workspace) async {
    final current = state;
    if (current is! WorkspaceLoaded || current.selected?.id == workspace.id) {
      return;
    }
    if (!current.workspaces.any((item) => item.id == workspace.id)) return;

    emit(current.copyWith(selected: workspace, creationError: null));
    await _selectionStorage.save(workspace.id);
  }

  Future<bool> createWorkspace(String name, String color) async {
    final current = state;
    if (current is! WorkspaceLoaded || current.isCreating) return false;

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      emit(current.copyWith(creationError: 'Введите название workspace.'));
      return false;
    }

    emit(current.copyWith(isCreating: true, creationError: null));
    try {
      final workspace = await _repository.createWorkspace(
        CreateWorkspaceRequest(name: trimmedName, color: color),
      );
      if (isClosed) return false;
      final latest = state;
      if (latest is! WorkspaceLoaded) return false;
      final workspaces = <WorkspaceModel>[
        ...latest.workspaces.where((item) => item.id != workspace.id),
        workspace,
      ];
      emit(
        latest.copyWith(
          workspaces: workspaces,
          selected: workspace,
          isCreating: false,
          creationError: null,
        ),
      );
      await _selectionStorage.save(workspace.id);
      return true;
    } on WorkspaceException catch (error) {
      if (isClosed) return false;
      final latest = state;
      if (latest is WorkspaceLoaded) {
        emit(latest.copyWith(isCreating: false, creationError: error.message));
      }
      return false;
    } catch (_) {
      if (isClosed) return false;
      final latest = state;
      if (latest is WorkspaceLoaded) {
        emit(
          latest.copyWith(
            isCreating: false,
            creationError: 'Не удалось создать workspace.',
          ),
        );
      }
      return false;
    }
  }

  void clearCreationError() {
    final current = state;
    if (current is WorkspaceLoaded && current.creationError != null) {
      emit(current.copyWith(creationError: null));
    }
  }

  WorkspaceModel? _findSelected(
    List<WorkspaceModel> workspaces,
    String? selectedId,
  ) {
    if (workspaces.isEmpty) return null;
    for (final workspace in workspaces) {
      if (workspace.id == selectedId) return workspace;
    }
    return workspaces.first;
  }
}
