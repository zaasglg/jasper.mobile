import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/dashboard_layout.dart';
import '../../domain/dashboard_repository.dart';

class DashboardLayoutState extends Equatable {
  const DashboardLayoutState({
    this.workspaceId = '',
    this.userId = '',
    this.layout,
    this.draft,
    this.loading = false,
    this.editing = false,
    this.saving = false,
    this.error,
    this.revision = 0,
  });
  final String workspaceId, userId;
  final DashboardLayout? layout, draft;
  final bool loading, editing, saving;
  final String? error;
  final int revision;
  DashboardLayout? get current => editing ? draft : layout;
  DashboardLayoutState copyWith({
    String? workspaceId,
    String? userId,
    DashboardLayout? layout,
    DashboardLayout? draft,
    bool? loading,
    bool? editing,
    bool? saving,
    String? error,
    int? revision,
  }) => DashboardLayoutState(
    workspaceId: workspaceId ?? this.workspaceId,
    userId: userId ?? this.userId,
    layout: layout ?? this.layout,
    draft: draft ?? this.draft,
    loading: loading ?? this.loading,
    editing: editing ?? this.editing,
    saving: saving ?? this.saving,
    error: error,
    revision: revision ?? this.revision,
  );
  @override
  List<Object?> get props => [
    workspaceId,
    userId,
    layout,
    draft,
    loading,
    editing,
    saving,
    error,
    revision,
  ];
}

class DashboardLayoutCubit extends Cubit<DashboardLayoutState> {
  DashboardLayoutCubit(this.repository) : super(const DashboardLayoutState());
  final DashboardRepository repository;
  CancelToken? _loadToken;
  int _generation = 0;
  final Map<String, Future<dynamic>> _data = {};
  static String message(Object error) {
    if (error is DashboardException) return error.message;
    if (error is DioException && error.response?.statusCode == 403) {
      return 'Нет доступа к дашборду этого workspace';
    }
    return 'Не удалось сохранить или загрузить дашборд. Повторите попытку.';
  }

  Future<void> configure(
    String userId,
    String workspaceId, {
    bool refresh = false,
  }) async {
    if (!refresh &&
        state.userId == userId &&
        state.workspaceId == workspaceId) {
      return;
    }
    _loadToken?.cancel();
    final token = _loadToken = CancelToken();
    final generation = ++_generation;
    _data.clear();
    final keep = state.userId == userId && state.workspaceId == workspaceId;
    emit(
      keep
          ? state.copyWith(loading: true, revision: state.revision + 1)
          : DashboardLayoutState(
              workspaceId: workspaceId,
              userId: userId,
              loading: true,
            ),
    );
    if (workspaceId.isEmpty || userId.isEmpty) {
      emit(state.copyWith(loading: false));
      return;
    }
    try {
      final layout = await repository.load(workspaceId, cancelToken: token);
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(layout: layout, loading: false));
      }
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(loading: false, error: message(error)));
      }
    }
  }

  Future<void> refreshConfig() async {
    if (state.editing ||
        state.saving ||
        state.loading ||
        state.workspaceId.isEmpty) {
      return;
    }
    final generation = _generation;
    try {
      final layout = await repository.load(state.workspaceId);
      if (!isClosed &&
          generation == _generation &&
          !state.editing &&
          !state.saving &&
          layout != state.layout) {
        emit(state.copyWith(layout: layout));
      }
    } catch (_) {
      /* A background poll must preserve the current dashboard offline. */
    }
  }

  void enterEdit() {
    if (state.layout == null || state.loading || state.saving) return;
    emit(state.copyWith(draft: state.layout, editing: true));
  }

  void cancelEdit() {
    if (!state.saving) emit(state.copyWith(editing: false));
  }

  void _update(
    List<DashboardWidgetSlot> widgets, {
    Set<String> resized = const {},
  }) {
    if (!state.editing || state.saving) return;
    emit(
      state.copyWith(
        draft: state.draft!.withWidgets(widgets, resized: resized),
      ),
    );
  }

  void reorder(int oldIndex, int newIndex) {
    if (!state.editing || state.saving) return;
    final all = state.draft!.ordered;
    final visible = all
        .where((e) => e.visible && e.definition != null)
        .toList();
    if (oldIndex < 0 ||
        oldIndex >= visible.length ||
        newIndex < 0 ||
        newIndex >= visible.length) {
      return;
    }
    if (newIndex == oldIndex) return;
    visible.insert(newIndex, visible.removeAt(oldIndex));
    final visibleIds = visible.map((e) => e.instanceId).toSet();
    _update([
      ...visible,
      ...all.where((e) => !visibleIds.contains(e.instanceId)),
    ]);
  }

  void update(String instanceId, Map<String, dynamic> changes) {
    final all = state.current?.ordered ?? [];
    _update(
      all
          .map(
            (slot) => slot.instanceId != instanceId
                ? slot
                : DashboardWidgetSlot.fromJson({...slot.toJson(), ...changes}),
          )
          .toList(),
      resized: changes.containsKey('height') ? {instanceId} : {},
    );
  }

  void add(String id) {
    if (!state.editing || state.saving) return;
    final definition = DashboardWidgetDefinition.find(id);
    if (definition == null) return;
    final all = state.draft!.ordered;
    final hidden = all.where((e) => e.id == id && !e.visible).firstOrNull;
    if (hidden != null) {
      update(hidden.instanceId, {'visible': true});
      return;
    }
    if (!definition.duplicable && all.any((e) => e.id == id && e.visible)) {
      return;
    }
    final defaultSlot = DashboardLayout.defaults().widgets.firstWhere(
      (e) => e.id == id,
    );
    _update([
      ...all,
      defaultSlot.copyWith(
        instanceId: definition.duplicable
            ? '$id-mobile-${DateTime.now().microsecondsSinceEpoch}'
            : id,
        visible: true,
      ),
    ]);
  }

  void reset() {
    if (state.editing && !state.saving) {
      emit(state.copyWith(draft: DashboardLayout.defaults()));
    }
  }

  Future<bool> save() async {
    if (!state.editing || state.saving || state.draft == null) return false;
    final workspaceId = state.workspaceId, generation = _generation;
    final draft = state.draft!;
    final original = state.layout!;
    emit(state.copyWith(saving: true));
    try {
      final latest = await repository.load(workspaceId);
      if (isClosed || generation != _generation) return false;
      if (latest != original) {
        throw const DashboardException(
          'Настройки изменились на другом устройстве. Отмените редактирование и обновите дашборд.',
        );
      }
      final saved = await repository.save(workspaceId, draft);
      if (isClosed || generation != _generation) return false;
      emit(state.copyWith(layout: saved, editing: false, saving: false));
      return true;
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(saving: false, error: message(error)));
      }
      return false;
    }
  }

  Future<bool> saveWidgetOptions(
    String instanceId,
    Map<String, dynamic> changes,
  ) async {
    if (state.saving || state.loading || state.current == null) return false;
    DashboardLayout apply(DashboardLayout layout) {
      if (!layout.widgets.any((slot) => slot.instanceId == instanceId)) {
        throw const DashboardException(
          'Виджет был удалён на другом устройстве. Обновите дашборд.',
        );
      }
      return layout.copyWith(
        widgets: layout.widgets.map((slot) {
          if (slot.instanceId != instanceId) return slot;
          final patch = <String, dynamic>{...changes};
          for (final key in [
            'resourceModeByProject',
            'resourceNamesByProject',
          ]) {
            if (changes[key] is Map) {
              patch[key] = {
                ...(slot.options[key] as Map? ?? {}),
                ...changes[key] as Map,
              };
            }
          }
          return DashboardWidgetSlot.fromJson({...slot.toJson(), ...patch});
        }).toList(),
      );
    }

    if (state.editing) {
      emit(state.copyWith(draft: apply(state.draft!)));
      return true;
    }
    final generation = _generation, workspaceId = state.workspaceId;
    emit(state.copyWith(saving: true));
    try {
      final latest = await repository.load(workspaceId);
      if (isClosed || generation != _generation) return false;
      final saved = await repository.save(workspaceId, apply(latest));
      if (isClosed || generation != _generation) return false;
      emit(state.copyWith(layout: saved, saving: false));
      return true;
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(saving: false, error: message(error)));
      }
      return false;
    }
  }

  void refreshContent() {
    if (isClosed) return;
    _data.clear();
    emit(state.copyWith(revision: state.revision + 1));
  }

  Future<dynamic> data(String key, Future<dynamic> Function() load) =>
      _data.putIfAbsent(key, load);
  void retryData(String key) {
    _data.remove(key);
  }

  @override
  Future<void> close() {
    _loadToken?.cancel();
    _generation++;
    return super.close();
  }
}
