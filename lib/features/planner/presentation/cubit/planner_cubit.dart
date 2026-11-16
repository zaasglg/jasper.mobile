import '../../../assistant/data/services/assistant_task_changes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/planner_item_model.dart';
import '../../data/planner_changes.dart';
import '../../domain/repositories/planner_repository.dart';
import 'planner_state.dart';

class PlannerCubit extends Cubit<PlannerState> {
  PlannerCubit(this._repository) : super(const PlannerState()) {
    assistantTaskChanges.addListener(_onTasksChanged);
    plannerChanges.addListener(_onTasksChanged);
  }

  void _onTasksChanged() {
    if (!isClosed) refresh();
  }

  @override
  Future<void> close() {
    assistantTaskChanges.removeListener(_onTasksChanged);
    plannerChanges.removeListener(_onTasksChanged);
    return super.close();
  }

  final PlannerRepository _repository;
  bool _refreshPending = false;
  int _revision = 0;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await refresh();
  }

  Future<void> refresh() async {
    if (state.busyIds.isNotEmpty || state.isSaving) {
      _refreshPending = true;
      return;
    }
    _refreshPending = false;
    final revision = ++_revision;
    emit(state.copyWith(status: PlannerStatus.loading, clearError: true));
    try {
      final items = await _repository.load();
      if (isClosed || revision != _revision) {
        return;
      }
      emit(state.copyWith(status: PlannerStatus.success, items: items));
    } catch (e) {
      if (isClosed || revision != _revision) {
        return;
      }
      emit(state.copyWith(status: PlannerStatus.failure, error: _message(e)));
    }
  }

  String _message(Object e) =>
      e is PlannerException ? e.message : 'Не удалось обновить ежедневник.';
  void _failure(Object e) => emit(
    state.copyWith(
      actionError: _message(e),
      actionRevision: state.actionRevision + 1,
    ),
  );

  Future<bool> save({
    PlannerItemModel? item,
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {
    if (item?.external == true) return false;
    if (state.isSaving || state.busyIds.isNotEmpty) {
      return false;
    }
    ++_revision;
    emit(state.copyWith(isSaving: true));
    try {
      if (item == null) {
        await _repository.create(
          title: title,
          scheduledAt: scheduledAt,
          durationMinutes: durationMinutes,
        );
      } else {
        await _repository.update(
          item,
          title: item.isStandalone ? title : null,
          scheduledAt: scheduledAt,
          durationMinutes: durationMinutes,
        );
      }
      if (isClosed) return false;
      emit(state.copyWith(isSaving: false));
      await refresh();
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(isSaving: false));
      _failure(e);
      return false;
    }
  }

  Future<void> toggle(PlannerItemModel item) => _mutate(
    item,
    () => _repository.update(item, completed: !item.completed),
    item.copyWith(completed: !item.completed),
  );
  Future<bool> remove(PlannerItemModel item) async {
    if (isClosed ||
        item.external ||
        state.busyIds.contains(item.id) ||
        state.isSaving) {
      return false;
    }
    // Reconcile with the server instead of confirming an optimistic disappearance.
    _refreshPending = true;
    final removed = await _mutate(
      item,
      () => _repository.remove(item.id),
      null,
    );
    if (!removed || isClosed) return false;
    if (state.items.any((current) => current.id == item.id)) {
      _failure(
        const PlannerException(
          'Сервер снова вернул запись после удаления. Обновите ежедневник и повторите попытку.',
        ),
      );
      return false;
    }
    return true;
  }

  Future<bool> _mutate(
    PlannerItemModel item,
    Future<void> Function() request,
    PlannerItemModel? updated,
  ) async {
    if (isClosed ||
        item.external ||
        state.busyIds.contains(item.id) ||
        state.isSaving) {
      return false;
    }
    ++_revision;
    emit(
      state.copyWith(
        busyIds: {...state.busyIds, item.id},
        items: [
          for (final current in state.items)
            if (current.id != item.id) current else ?updated,
        ],
      ),
    );
    try {
      await request();
      if (isClosed) return false;
      emit(
        state.copyWith(
          status: PlannerStatus.success,
          busyIds: {...state.busyIds}..remove(item.id),
        ),
      );
      return true;
    } catch (e) {
      if (isClosed) return false;
      final items = [...state.items];
      final index = items.indexWhere((e) => e.id == item.id);
      if (index < 0) {
        items.add(item);
      } else {
        items[index] = item;
      }
      emit(
        state.copyWith(
          items: items,
          busyIds: {...state.busyIds}..remove(item.id),
        ),
      );
      _failure(e);
      return false;
    } finally {
      if (!isClosed && _refreshPending && state.busyIds.isEmpty) {
        await refresh();
      }
    }
  }

  Future<bool> addTask({
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {
    if (state.isSaving || state.busyIds.isNotEmpty) {
      return false;
    }
    ++_revision;
    emit(state.copyWith(isSaving: true));
    try {
      final existing = state.items
          .where(
            (item) =>
                (taskId != null && item.taskId == taskId) ||
                (inboxTaskId != null && item.inboxTaskId == inboxTaskId),
          )
          .firstOrNull;
      if (existing != null) {
        await _repository.update(
          existing,
          scheduledAt: scheduledAt,
          durationMinutes: durationMinutes,
        );
      } else {
        await _repository.addTask(
          projectId: projectId,
          taskId: taskId,
          inboxTaskId: inboxTaskId,
          scheduledAt: scheduledAt,
          durationMinutes: durationMinutes,
        );
      }
      if (isClosed) return false;
      emit(state.copyWith(isSaving: false));
      await refresh();
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(isSaving: false));
      _failure(e);
      return false;
    }
  }
}
