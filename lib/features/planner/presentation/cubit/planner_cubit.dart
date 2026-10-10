import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/planner_item_model.dart';
import '../../domain/repositories/planner_repository.dart';
import 'planner_state.dart';

class PlannerCubit extends Cubit<PlannerState> {
  PlannerCubit(this._repository) : super(const PlannerState());
  final PlannerRepository _repository;
  int _revision = 0;
  int _workspaceRevision = 0;

  Future<void> configure(String workspaceId) async {
    if (state.workspaceId == workspaceId) return;
    _workspaceRevision++;
    emit(PlannerState(workspaceId: workspaceId));
    if (workspaceId.isNotEmpty) await refresh();
  }

  Future<void> refresh() async {
    if (state.workspaceId.isEmpty ||
        state.busyIds.isNotEmpty ||
        state.isSaving) {
      return;
    }
    final revision = ++_revision;
    final workspaceId = state.workspaceId;
    emit(state.copyWith(status: PlannerStatus.loading, clearError: true));
    try {
      final items = await _repository.load(workspaceId);
      if (isClosed ||
          revision != _revision ||
          workspaceId != state.workspaceId) {
        return;
      }
      emit(state.copyWith(status: PlannerStatus.success, items: items));
    } catch (e) {
      if (isClosed ||
          revision != _revision ||
          workspaceId != state.workspaceId) {
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
    if (state.isSaving ||
        state.workspaceId.isEmpty ||
        state.busyIds.isNotEmpty) {
      return false;
    }
    final workspaceId = state.workspaceId;
    final generation = _workspaceRevision;
    ++_revision;
    emit(state.copyWith(isSaving: true));
    try {
      if (item == null) {
        await _repository.create(
          workspaceId,
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
      if (isClosed || generation != _workspaceRevision) return false;
      emit(state.copyWith(isSaving: false));
      await refresh();
      return true;
    } catch (e) {
      if (isClosed || generation != _workspaceRevision) return false;
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
  Future<void> remove(PlannerItemModel item) =>
      _mutate(item, () => _repository.remove(item.id), null);
  Future<void> _mutate(
    PlannerItemModel item,
    Future<void> Function() request,
    PlannerItemModel? updated,
  ) async {
    if (state.busyIds.contains(item.id) || state.isSaving) return;
    final generation = _workspaceRevision;
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
      if (isClosed || generation != _workspaceRevision) return;
      emit(
        state.copyWith(
          status: PlannerStatus.success,
          busyIds: {...state.busyIds}..remove(item.id),
        ),
      );
    } catch (e) {
      if (isClosed || generation != _workspaceRevision) return;
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
    }
  }

  Future<bool> addTask({
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {
    if (state.isSaving ||
        state.workspaceId.isEmpty ||
        state.busyIds.isNotEmpty) {
      return false;
    }
    final generation = _workspaceRevision;
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
          state.workspaceId,
          projectId: projectId,
          taskId: taskId,
          inboxTaskId: inboxTaskId,
          scheduledAt: scheduledAt,
          durationMinutes: durationMinutes,
        );
      }
      if (isClosed || generation != _workspaceRevision) return false;
      emit(state.copyWith(isSaving: false));
      await refresh();
      return true;
    } catch (e) {
      if (isClosed || generation != _workspaceRevision) return false;
      emit(state.copyWith(isSaving: false));
      _failure(e);
      return false;
    }
  }
}
