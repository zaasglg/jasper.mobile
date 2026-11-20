import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/inbox_task_model.dart';
import '../../data/repositories/inbox_repository_impl.dart';
import '../../data/services/inbox_home_widget_service.dart';
import '../../domain/repositories/inbox_repository.dart';
import 'inbox_state.dart';

class InboxCubit extends Cubit<InboxState> {
  InboxCubit(this._repository) : super(const InboxState());

  final InboxRepository _repository;
  final Set<String> _actionIds = {};

  Future<String?> runAction(
    String id,
    Future<void> Function(InboxActionsRepository repository) action,
  ) async {
    if (!_actionIds.add(id)) return 'Изменения задачи уже сохраняются.';
    _loadRevision++;
    _reloadPending = true;
    try {
      final repository = _repository;
      if (repository is! InboxActionsRepository) return 'Действие недоступно.';
      await action(repository as InboxActionsRepository);
      _loadRevision++;
      if (!isClosed) await load();
      return null;
    } on InboxException catch (error) {
      return error.message;
    } catch (_) {
      return 'Не удалось изменить задачу. Попробуйте ещё раз.';
    } finally {
      _actionIds.remove(id);
      await _flushReload();
    }
  }

  int _loadRevision = 0;
  bool _reloadPending = false;

  Future<void> _flushReload() async {
    if (!isClosed &&
        _reloadPending &&
        !state.isCreating &&
        state.completingTaskIds.isEmpty &&
        _actionIds.isEmpty) {
      await _load();
    }
  }

  Future<void> load() => _load();

  Future<void> _load({bool duringCreate = false}) async {
    if (isClosed) return;
    if ((!duringCreate && state.isCreating) ||
        state.completingTaskIds.isNotEmpty ||
        _actionIds.isNotEmpty) {
      _reloadPending = true;
      return;
    }
    _reloadPending = false;
    final revision = ++_loadRevision;
    emit(
      state.copyWith(
        status: state.tasks.isEmpty ? InboxStatus.loading : InboxStatus.success,
        clearError: true,
      ),
    );
    try {
      final tasks = (await _repository.getInbox(
        archived: false,
        sort: 1,
      )).where((task) => !task.archived).toList(growable: false);
      if (revision != _loadRevision || isClosed) return;
      emit(
        state.copyWith(
          status: InboxStatus.success,
          tasks: tasks,
          clearError: true,
        ),
      );
      unawaited(InboxHomeWidgetService.sync(tasks));
    } on InboxException catch (error) {
      if (revision != _loadRevision || isClosed) return;
      emit(
        state.copyWith(
          status: state.tasks.isEmpty
              ? InboxStatus.failure
              : InboxStatus.success,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      if (revision != _loadRevision || isClosed) return;
      emit(
        state.copyWith(
          status: state.tasks.isEmpty
              ? InboxStatus.failure
              : InboxStatus.success,
          errorMessage: 'Не удалось загрузить задачи Инбокса.',
        ),
      );
    }
  }

  Future<bool> create(String title) async {
    final value = title.trim();
    if (value.isEmpty || state.isCreating) return false;
    _loadRevision++;
    _reloadPending = true;
    emit(state.copyWith(isCreating: true, clearCreationError: true));
    try {
      await _repository.createInbox(title: value);
      if (isClosed) return false;
      // A failed refresh must not turn an acknowledged POST into a failed create.
      await _load(duringCreate: true);
      if (isClosed) return true;
      emit(state.copyWith(isCreating: false, clearCreationError: true));
      return true;
    } on InboxException catch (error) {
      if (isClosed) return false;
      emit(
        state.copyWith(isCreating: false, creationErrorMessage: error.message),
      );
      return false;
    } catch (_) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isCreating: false,
          creationErrorMessage: 'Не удалось создать задачу Инбокса.',
        ),
      );
      return false;
    } finally {
      await _flushReload();
    }
  }

  Future<bool> complete(String taskId) async {
    if (taskId.isEmpty || state.completingTaskIds.contains(taskId)) {
      return false;
    }
    _loadRevision++;
    _reloadPending = true;
    emit(
      state.copyWith(
        completingTaskIds: <String>{...state.completingTaskIds, taskId},
        clearCompletionError: true,
      ),
    );
    try {
      await _repository.completeInboxTask(id: taskId);
      _loadRevision++;
      if (isClosed) return false;
      final tasks = state.tasks
          .where((task) => task.id != taskId)
          .toList(growable: false);
      final completingIds = <String>{...state.completingTaskIds}
        ..remove(taskId);
      emit(
        state.copyWith(
          tasks: tasks,
          completingTaskIds: completingIds,
          clearCompletionError: true,
        ),
      );
      unawaited(InboxHomeWidgetService.sync(tasks));
      return true;
    } on InboxException catch (error) {
      if (isClosed) return false;
      final completingIds = <String>{...state.completingTaskIds}
        ..remove(taskId);
      emit(
        state.copyWith(
          completingTaskIds: completingIds,
          completionErrorMessage: error.message,
        ),
      );
      return false;
    } catch (_) {
      if (isClosed) return false;
      final completingIds = <String>{...state.completingTaskIds}
        ..remove(taskId);
      emit(
        state.copyWith(
          completingTaskIds: completingIds,
          completionErrorMessage: 'Не удалось завершить задачу Инбокса.',
        ),
      );
      return false;
    } finally {
      await _flushReload();
    }
  }

  void addLocal(String title) {
    final value = title.trim();
    if (value.isEmpty) return;
    final task = InboxTaskModel(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      title: value,
      createdAt: DateTime.now(),
      isLocalOnly: true,
    );
    emit(
      state.copyWith(
        status: InboxStatus.success,
        tasks: <InboxTaskModel>[task, ...state.tasks],
      ),
    );
    unawaited(InboxHomeWidgetService.sync(state.tasks));
  }

  void toggleLocal(String taskId) {
    emit(
      state.copyWith(
        tasks: state.tasks
            .map(
              (task) => task.id == taskId
                  ? task.copyWith(completed: !task.completed)
                  : task,
            )
            .toList(growable: false),
      ),
    );
    unawaited(InboxHomeWidgetService.sync(state.tasks));
  }

  void removeLocal(String taskId) {
    emit(
      state.copyWith(
        tasks: state.tasks
            .where((task) => task.id != taskId)
            .toList(growable: false),
      ),
    );
    unawaited(InboxHomeWidgetService.sync(state.tasks));
  }
}
