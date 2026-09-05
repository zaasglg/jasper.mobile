import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/inbox_task_model.dart';
import '../../data/repositories/inbox_repository_impl.dart';
import '../../data/services/inbox_home_widget_service.dart';
import '../../domain/repositories/inbox_repository.dart';
import 'inbox_state.dart';

class InboxCubit extends Cubit<InboxState> {
  InboxCubit(this._repository) : super(const InboxState());

  final InboxRepository _repository;
  int _loadRevision = 0;

  Future<void> load() async {
    final revision = ++_loadRevision;
    emit(state.copyWith(status: InboxStatus.loading, clearError: true));
    try {
      final tasks = await _repository.getInbox(archived: true, sort: 1);
      if (revision != _loadRevision || isClosed) return;
      emit(InboxState(status: InboxStatus.success, tasks: tasks));
      unawaited(InboxHomeWidgetService.sync(tasks));
    } on InboxException catch (error) {
      if (revision != _loadRevision || isClosed) return;
      emit(
        state.copyWith(
          status: InboxStatus.failure,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      if (revision != _loadRevision || isClosed) return;
      emit(
        state.copyWith(
          status: InboxStatus.failure,
          errorMessage: 'Не удалось загрузить задачи Инбокса.',
        ),
      );
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
