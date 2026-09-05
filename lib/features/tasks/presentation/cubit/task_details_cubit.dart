import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../data/models/task_detail_model.dart';
import '../../domain/repositories/task_details_repository.dart';
import 'task_details_state.dart';

class TaskDetailsCubit extends Cubit<TaskDetailsState> {
  TaskDetailsCubit(this._repository, this._profileRepository)
    : super(const TaskDetailsState());

  final TaskDetailsRepository _repository;
  final ProfileRepository _profileRepository;

  Future<void> load(String taskId, {ProjectTaskModel? initialTask}) async {
    emit(
      state.copyWith(
        status: TaskDetailsStatus.loading,
        task: initialTask,
        clearError: true,
      ),
    );
    try {
      final payload = await _repository.getTask(taskId);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: TaskDetailsStatus.success,
          task: payload.task,
          detail: payload.detail,
          resources: payload.resources,
          clearError: true,
        ),
      );
      await _loadSecondaryData(taskId, payload.task.projectId);
    } on TaskDetailsException catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: TaskDetailsStatus.failure,
          errorMessage: error.message,
        ),
      );
    }
  }

  Future<void> refresh() async {
    final task = state.task;
    if (task == null) return;
    await load(task.id, initialTask: task);
  }

  Future<void> toggleCompleted() async {
    final task = state.task;
    if (task == null || state.isSaving) return;
    final oldTask = task;
    final progress = task.isDone ? 0 : 100;
    emit(
      state.copyWith(
        task: task.copyWith(progress: progress.toDouble()),
        isSaving: true,
        clearActionError: true,
      ),
    );
    try {
      final payload = await _repository.updateProgress(task.id, progress);
      _applyPayload(payload);
    } on TaskDetailsException catch (error) {
      _rollback(error.message, task: oldTask);
    }
  }

  Future<void> updateDescription(String description) async {
    final updated = state.detail.copyWith(description: description.trim());
    await _saveDetail(updated);
  }

  Future<void> updateDeadline(DateTime? deadline) async {
    final task = state.task;
    if (task == null || state.isSaving) return;
    final oldTask = task;
    emit(
      state.copyWith(
        task: task.copyWith(end: deadline),
        isSaving: true,
        clearActionError: true,
      ),
    );
    try {
      final payload = await _repository.updateEnd(task.id, deadline);
      _applyPayload(payload);
    } on TaskDetailsException catch (error) {
      _rollback(error.message, task: oldTask);
    }
  }

  Future<void> toggleChecklistItem(String checklistId, String itemId) async {
    final updatedChecklists = state.detail.checklists
        .map((checklist) {
          if (checklist.id != checklistId) return checklist;
          return checklist.copyWith(
            items: checklist.items
                .map(
                  (item) => item.id == itemId
                      ? item.copyWith(done: !item.done)
                      : item,
                )
                .toList(growable: false),
            sections: checklist.sections
                .map((section) {
                  return section.copyWith(
                    items: section.items
                        .map(
                          (item) => item.id == itemId
                              ? item.copyWith(done: !item.done)
                              : item,
                        )
                        .toList(growable: false),
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);
    await _saveDetail(state.detail.copyWith(checklists: updatedChecklists));
  }

  Future<void> addComment(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    final now = DateTime.now();
    final user = state.currentUser;
    final comment = TaskCommentModel(
      id: 'comment_${now.millisecondsSinceEpoch}_mobile',
      author: user?.name.trim().isNotEmpty == true
          ? user!.name.trim()
          : 'Пользователь',
      authorId: user?.id,
      time: now.toIso8601String(),
      text: value,
    );
    await _saveDetail(
      state.detail.copyWith(
        comments: <TaskCommentModel>[...state.detail.comments, comment],
      ),
    );
  }

  Future<void> _loadSecondaryData(String taskId, String projectId) async {
    try {
      final columns = await _repository.getColumns(projectId);
      if (!isClosed) emit(state.copyWith(columns: columns));
    } on TaskDetailsException {
      // Built-in status labels remain available when columns cannot be loaded.
    }
    try {
      final history = await _repository.getHistory(taskId);
      if (!isClosed) emit(state.copyWith(history: history));
    } on TaskDetailsException {
      // History is supplementary; the task stays usable when it is unavailable.
    }
    try {
      final user = await _profileRepository.getCurrentUser();
      if (!isClosed) emit(state.copyWith(currentUser: user));
    } catch (_) {
      // Comments still work with a neutral author label if profile loading fails.
    }
  }

  Future<void> _saveDetail(TaskDetailModel updated) async {
    final task = state.task;
    if (task == null || state.isSaving) return;
    final oldDetail = state.detail;
    emit(
      state.copyWith(detail: updated, isSaving: true, clearActionError: true),
    );
    try {
      final payload = await _repository.updateDetail(task.id, updated);
      _applyPayload(payload);
      await _reloadHistory(task.id);
    } on TaskDetailsException catch (error) {
      _rollback(error.message, detail: oldDetail);
    }
  }

  Future<void> _reloadHistory(String taskId) async {
    try {
      final history = await _repository.getHistory(taskId);
      if (!isClosed) emit(state.copyWith(history: history));
    } on TaskDetailsException {
      // A failed history refresh must not roll back a successfully saved task.
    }
  }

  void _applyPayload(TaskDetailsPayload payload) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: TaskDetailsStatus.success,
        task: payload.task,
        detail: payload.detail,
        resources: payload.resources,
        isSaving: false,
        clearActionError: true,
      ),
    );
  }

  void _rollback(
    String message, {
    ProjectTaskModel? task,
    TaskDetailModel? detail,
  }) {
    if (isClosed) return;
    emit(
      state.copyWith(
        task: task,
        detail: detail,
        isSaving: false,
        actionErrorMessage: message,
        actionRevision: state.actionRevision + 1,
      ),
    );
  }
}
