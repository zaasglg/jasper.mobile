import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/workspace_selection_storage.dart';
import '../../domain/entities/create_workspace_request.dart';
import '../../domain/entities/workspace_model.dart';
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
    final selection = _selectionStorage.stageSelection(id);
    final result = _selectionWrites
        .then((_) async {
          if (isClosed) return;
          if (id == null) {
            await _selectionStorage.clear();
          } else {
            await _selectionStorage.save(id);
          }
        })
        .whenComplete(() => _selectionStorage.finishSelection(selection));
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
        _selectionStorage.readScope(),
      ]);
      if (isClosed) return;
      final workspaces = results[0] as List<WorkspaceModel>;
      final savedId = results[1] as String?;
      final savedScope = results[2] as List<String>?;
      final latest = state;
      final selectedId = latest is WorkspaceLoaded
          ? latest.selected?.id
          : savedId;
      var selected = _findSelected(workspaces, selectedId);
      final previousScope = latest is WorkspaceLoaded
          ? latest.effectiveSelectedIds
          : savedScope?.toSet() ?? <String>{};
      final isAll = latest is WorkspaceLoaded
          ? latest.allSelected
          : savedScope?.isEmpty == true;
      final availableScope = workspaces
          .where((w) => previousScope.contains(w.id))
          .toList();
      if (!isAll &&
          availableScope.isNotEmpty &&
          !previousScope.contains(selected?.id)) {
        selected = availableScope.first;
      }
      final selectionRevision = _selectionRevision;
      if (selected == null) {
        await _writeSelection(null);
      } else if (selected.id != savedId) {
        await _writeSelection(selected.id);
      }
      if (isClosed) return;
      final current = state;
      var effectiveSelection =
          selectionRevision != _selectionRevision && current is WorkspaceLoaded
          ? _findSelected(workspaces, current.selected?.id)
          : selected;
      final allSelected = current is WorkspaceLoaded
          ? current.allSelected
          : savedScope?.isEmpty == true;
      final scope =
          (current is WorkspaceLoaded
                  ? current.effectiveSelectedIds
                  : savedScope?.toSet() ?? <String>{})
              .intersection(workspaces.map((w) => w.id).toSet());
      if (scope.isEmpty && effectiveSelection != null) {
        scope.add(effectiveSelection.id);
      }
      if (!allSelected &&
          scope.isNotEmpty &&
          !scope.contains(effectiveSelection?.id)) {
        effectiveSelection = workspaces.firstWhere((w) => scope.contains(w.id));
      }
      emit(
        current is WorkspaceLoaded
            ? current.copyWith(
                workspaces: workspaces,
                selected: effectiveSelection,
                selectedIds: Set.unmodifiable(scope),
                allSelected: allSelected,
                isRefreshing: false,
                refreshError: null,
              )
            : WorkspaceLoaded(
                workspaces: workspaces,
                selected: effectiveSelection,
                selectedIds: Set.unmodifiable(scope),
                allSelected: allSelected,
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
        current.selected?.id == workspace.id &&
            current.effectiveSelectedIds.length == 1 &&
            !current.allSelected) {
      return;
    }
    if (!current.workspaces.any((item) => item.id == workspace.id)) return;

    final selected = current.workspaces.firstWhere(
      (item) => item.id == workspace.id,
    );
    final revision = ++_selectionRevision;
    final write = _writeScope(workspace.id, {workspace.id});
    emit(
      current.copyWith(
        selected: selected,
        selectedIds: {selected.id},
        allSelected: false,
        creationError: null,
      ),
    );
    try {
      await write;
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
        final restored = current.effectiveSelectedIds.intersection(
          latest.workspaces.map((w) => w.id).toSet(),
        );
        final selected = _findSelected(latest.workspaces, current.selected?.id);
        if (restored.isEmpty && selected != null) restored.add(selected.id);
        final rollback = selected == null
            ? _writeSelection(null)
            : _writeScope(selected.id, restored, all: current.allSelected);
        emit(
          latest.copyWith(
            selected: selected,
            selectedIds: Set.unmodifiable(restored),
            allSelected: current.allSelected,
            refreshError: 'Не удалось сохранить выбор workspace.',
          ),
        );
        try {
          await rollback;
        } catch (_) {}
      }
    }
  }

  Future<void> _writeScope(String id, Set<String> ids, {bool all = false}) {
    final primary = _writeSelection(id);
    final result = _selectionWrites.then((_) async {
      await primary;
      await _selectionStorage.saveScope(all ? const [] : ids);
    });
    _selectionWrites = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> toggle(WorkspaceModel workspace) async {
    final current = state;
    if (current is! WorkspaceLoaded ||
        !current.workspaces.any((w) => w.id == workspace.id)) {
      return;
    }
    final ids = {...current.effectiveSelectedIds};
    if (ids.contains(workspace.id)) {
      if (ids.length == 1) return;
      ids.remove(workspace.id);
    } else {
      ids.add(workspace.id);
    }
    await _changeScope(current, ids, all: false);
  }

  Future<void> selectAll() async {
    final current = state;
    if (current is! WorkspaceLoaded || current.workspaces.isEmpty) return;
    await _changeScope(
      current,
      current.workspaces.map((w) => w.id).toSet(),
      all: true,
    );
  }

  Future<void> _changeScope(
    WorkspaceLoaded current,
    Set<String> ids, {
    required bool all,
  }) async {
    final primary = ids.contains(current.selected?.id)
        ? current.selected!
        : current.workspaces.firstWhere((w) => ids.contains(w.id));
    final revision = ++_selectionRevision;
    final write = _writeScope(primary.id, ids, all: all);
    emit(
      current.copyWith(
        selected: primary,
        selectedIds: Set.unmodifiable(ids),
        allSelected: all,
        refreshError: null,
      ),
    );
    try {
      await write;
    } catch (_) {
      final latest = state;
      if (!isClosed &&
          revision == _selectionRevision &&
          latest is WorkspaceLoaded) {
        final restored = current.effectiveSelectedIds.intersection(
          latest.workspaces.map((w) => w.id).toSet(),
        );
        final selected = _findSelected(latest.workspaces, current.selected?.id);
        if (restored.isEmpty && selected != null) restored.add(selected.id);
        emit(
          latest.copyWith(
            selected: selected,
            selectedIds: restored,
            allSelected: current.allSelected,
            refreshError: 'Не удалось сохранить выбор workspace.',
          ),
        );
        if (selected != null) {
          try {
            await _writeScope(selected.id, restored, all: current.allSelected);
          } catch (_) {}
        }
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
