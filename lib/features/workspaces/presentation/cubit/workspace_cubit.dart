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

  Future<void>? _activeLoad;
  Future<void> _selectionWrites = Future<void>.value();
  int _selectionRevision = 0;

  Future<void> _writeSelection(String? id) {
    final result = _selectionWrites.then((_) async {
      if (isClosed) return;
      if (id == null) {
        await _selectionStorage.clear();
      } else {
        await _selectionStorage.save(id);
      }
    });
    _selectionWrites = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> load({bool force = false}) {
    if (isClosed) return Future.value();
    if (_activeLoad != null) return _activeLoad!;
    final current = state;
    if (current is WorkspaceLoaded && (!force || current.isCreating)) {
      return Future.value();
    }
    _activeLoad = _load().whenComplete(() => _activeLoad = null);
    return _activeLoad!;
  }

  Future<void> _load() async {
    final previous = state;
    if (previous is WorkspaceLoaded) {
      emit(previous.copyWith(isRefreshing: true, refreshError: null));
    } else {
      emit(const WorkspaceLoading());
    }
    try {
      final results = await Future.wait<dynamic>([
        _repository.getWorkspaces(),
        _selectionStorage.read(),
      ]);
      if (isClosed) return;
      final workspaces = results[0] as List<WorkspaceModel>;
      final savedId = results[1] as String?;
      final latest = state;
      final selectedId = latest is WorkspaceLoaded
          ? latest.selected?.id
          : savedId;
      final selected = _findSelected(workspaces, selectedId);
      final selectionRevision = _selectionRevision;
      if (selected == null) {
        await _writeSelection(null);
      } else if (selected.id != savedId) {
        await _writeSelection(selected.id);
      }
      if (isClosed) return;
      final current = state;
      final effectiveSelection =
          selectionRevision != _selectionRevision && current is WorkspaceLoaded
          ? _findSelected(workspaces, current.selected?.id)
          : selected;
      emit(
        current is WorkspaceLoaded
            ? current.copyWith(
                workspaces: workspaces,
                selected: effectiveSelection,
                isRefreshing: false,
                refreshError: null,
              )
            : WorkspaceLoaded(
                workspaces: workspaces,
                selected: effectiveSelection,
              ),
      );
      if (current is WorkspaceLoaded && current.hasLoadedArchived) {
        await loadArchived();
      }
    } catch (error) {
      if (isClosed) return;
      final message = error is WorkspaceException
          ? error.message
          : 'Не удалось обновить workspace.';
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(current.copyWith(isRefreshing: false, refreshError: message));
      } else {
        emit(WorkspaceFailure(message));
      }
    }
  }

  Future<void> loadArchived() async {
    final current = state;
    if (current is! WorkspaceLoaded || current.isLoadingArchived || isClosed) {
      return;
    }
    emit(current.copyWith(isLoadingArchived: true, archivedError: null));
    try {
      final workspaces = await _repository.getArchivedWorkspaces();
      final latest = state;
      if (!isClosed && latest is WorkspaceLoaded) {
        emit(
          latest.copyWith(
            archivedWorkspaces: workspaces,
            isLoadingArchived: false,
            hasLoadedArchived: true,
            archivedError: null,
          ),
        );
      }
    } catch (error) {
      final latest = state;
      if (!isClosed && latest is WorkspaceLoaded) {
        emit(
          latest.copyWith(
            isLoadingArchived: false,
            archivedError: error is WorkspaceException
                ? error.message
                : 'Не удалось загрузить архив workspace.',
          ),
        );
      }
    }
  }

  Future<void> select(WorkspaceModel workspace) async {
    final current = state;
    if (isClosed ||
        current is! WorkspaceLoaded ||
        current.selected?.id == workspace.id) {
      return;
    }
    if (!current.workspaces.any((item) => item.id == workspace.id)) return;

    final selected = current.workspaces.firstWhere(
      (item) => item.id == workspace.id,
    );
    final revision = ++_selectionRevision;
    emit(current.copyWith(selected: selected, creationError: null));
    try {
      await _writeSelection(workspace.id);
      final latest = state;
      if (!isClosed &&
          revision == _selectionRevision &&
          latest is WorkspaceLoaded &&
          !latest.workspaces.any((item) => item.id == selected.id)) {
        await _writeSelection(latest.selected?.id);
      }
    } catch (_) {
      final latest = state;
      if (!isClosed &&
          revision == _selectionRevision &&
          latest is WorkspaceLoaded) {
        emit(
          latest.copyWith(
            selected: _findSelected(latest.workspaces, current.selected?.id),
            refreshError: 'Не удалось сохранить выбор workspace.',
          ),
        );
      }
    }
  }

  Future<bool> createWorkspace(String name, String color) async {
    if (_activeLoad != null) await _activeLoad;
    if (isClosed) return false;
    final current = state;
    if (current is! WorkspaceLoaded || current.isCreating) return false;

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      emit(current.copyWith(creationError: 'Введите название workspace.'));
      return false;
    }

    emit(current.copyWith(isCreating: true, creationError: null));
    final selectionRevision = _selectionRevision;
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
      emit(latest.copyWith(workspaces: workspaces, creationError: null));
      if (selectionRevision == _selectionRevision) await select(workspace);
      if (isClosed) return true;
      final updated = state;
      if (updated is WorkspaceLoaded) emit(updated.copyWith(isCreating: false));
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
