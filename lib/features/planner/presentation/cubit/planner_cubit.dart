import '../../../tasks/data/models/task_detail_model.dart';
import 'dart:async';
import '../../domain/repositories/task_icon_repository.dart';
import '../../../assistant/data/services/assistant_task_changes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/planner_item_model.dart';
import '../../data/planner_changes.dart';
import '../../domain/repositories/planner_repository.dart';
import 'planner_state.dart';

class PlannerCubit extends Cubit<PlannerState> {
  PlannerCubit(this._repository, {TaskIconRepository? iconRepository})
    : _iconRepository = iconRepository,
      super(const PlannerState()) {
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
  final TaskIconRepository? _iconRepository;
  final _iconsPending = <String>{};
  bool _refreshPending = false;
  int _revision = 0;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await refresh();
  }

  Future<void> refresh() async {
    if (isClosed) return;
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
      unawaited(_loadIcons(items));
    } catch (e) {
      if (isClosed || revision != _revision) {
        return;
      }
      emit(state.copyWith(status: PlannerStatus.failure, error: _message(e)));
    }
  }

  Future<void> _loadIcons(List<PlannerItemModel> items) async {
    final repository = _iconRepository;
    if (repository == null) return;
    final titles = items
        .where((item) => !item.external && item.icon == null)
        .map((item) => plannerIconTitle(item.title))
        .where(
          (title) =>
              title.isNotEmpty &&
              !state.taskIcons.containsKey(title) &&
              !_iconsPending.contains(title),
        )
        .toSet()
        .toList();
    if (titles.isEmpty) return;
    _iconsPending.addAll(titles);
    emit(state.copyWith(iconsLoading: true));
    try {
      final icons = await repository.getIcons(titles);
      if (isClosed) return;
      final current = state.items
          .map((item) => plannerIconTitle(item.title))
          .toSet();
      emit(
        state.copyWith(
          taskIcons: {
            for (final entry in state.taskIcons.entries)
              if (current.contains(entry.key)) entry.key: entry.value,
            for (final entry in icons.entries)
              if (current.contains(entry.key)) entry.key: entry.value,
          },
        ),
      );
    } catch (_) {
      // Decorative icons must never block planning or change task lifecycle.
    } finally {
      _iconsPending.removeAll(titles);
      if (!isClosed) {
        emit(state.copyWith(iconsLoading: _iconsPending.isNotEmpty));
      }
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

  void _invalidateRefresh() {
    // A write invalidates any running read; reconcile after writes even on error.
    if (state.status == PlannerStatus.loading) _refreshPending = true;
    ++_revision;
  }

  Future<void> _refreshIfPending() async {
    if (!isClosed &&
        _refreshPending &&
        state.busyIds.isEmpty &&
        !state.isSaving) {
      await refresh();
    }
  }

  Future<bool> save({
    PlannerItemModel? item,
    required String title,
    required DateTime? scheduledAt,
    DateTime? plannedDate,
    required int durationMinutes,
    int? reminderMinutes,
  }) async {
    if (item?.external == true) return false;
    if (state.isSaving || state.busyIds.isNotEmpty) {
      return false;
    }
    _invalidateRefresh();
    emit(
      state.copyWith(
        isSaving: true,
        status: PlannerStatus.success,
        clearError: true,
      ),
    );
    try {
      if (item == null) {
        await _repository.create(
          title: title,
          scheduledAt: scheduledAt,
          plannedDate: plannedDate,
          durationMinutes: durationMinutes,
        );
      } else {
        await _repository.update(
          item,
          title: item.isStandalone ? title : null,
          reminderMinutes: reminderMinutes,
          scheduledAt: scheduledAt,
          plannedDate: plannedDate,
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
    } finally {
      await _refreshIfPending();
    }
  }

  Future<bool> updateExtras(
    PlannerItemModel item, {
    bool updateIcon = false,
    String? icon,
    List<TaskChecklistModel>? checklists,
  }) async {
    if (checklists != null && !item.isStandalone) return false;
    final current = state.items
        .where((entry) => entry.id == item.id)
        .firstOrNull;
    if (current == null) return false;
    final success = await _mutate(
      current,
      () => _repository.updateExtras(
        item.id,
        updateIcon: updateIcon,
        icon: icon,
        checklists: checklists,
      ),
      current.copyWith(
        icon: updateIcon ? icon : current.icon,
        checklists: checklists,
      ),
    );
    if (success && updateIcon && icon == null && !isClosed) {
      unawaited(_loadIcons(state.items));
    }
    return success;
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
    _invalidateRefresh();
    emit(
      state.copyWith(
        status: PlannerStatus.success,
        clearError: true,
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
      await _refreshIfPending();
    }
  }

  Future<bool> addTask({
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime? scheduledAt,
    DateTime? plannedDate,
    required int durationMinutes,
  }) async {
    if (state.isSaving || state.busyIds.isNotEmpty) {
      return false;
    }
    _invalidateRefresh();
    emit(
      state.copyWith(
        isSaving: true,
        status: PlannerStatus.success,
        clearError: true,
      ),
    );
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
          plannedDate: plannedDate,
          durationMinutes: durationMinutes,
        );
      } else {
        await _repository.addTask(
          projectId: projectId,
          taskId: taskId,
          inboxTaskId: inboxTaskId,
          scheduledAt: scheduledAt,
          plannedDate: plannedDate,
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
    } finally {
      await _refreshIfPending();
    }
  }
}
