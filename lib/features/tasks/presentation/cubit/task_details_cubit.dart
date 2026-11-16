import '../../data/models/task_label_catalog.dart';
import '../../../assistant/data/services/assistant_task_changes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../data/models/task_detail_model.dart';
import '../../domain/repositories/task_details_repository.dart';
import '../../domain/utils/task_completion.dart';
import 'task_details_state.dart';

class TaskDetailsCubit extends Cubit<TaskDetailsState> {
  TaskDetailsCubit(this._repository, this._profileRepository)
    : super(const TaskDetailsState()) {
    assistantTaskChanges.addListener(_onAiTasksChanged);
  }

  void _onAiTasksChanged() {
    if (!isClosed && state.task != null && !state.isSaving) refresh();
  }

  @override
  Future<void> close() {
    assistantTaskChanges.removeListener(_onAiTasksChanged);
    return super.close();
  }

  int _loadRevision = 0;
  final TaskDetailsRepository _repository;
  final ProfileRepository _profileRepository;

  Future<void> updateEstimate(int minutes) async {
    final task = state.task;
    final repository = _repository;
    if (task == null || state.isSaving || minutes < 0) return;
    if (repository is! TaskTimingRepository) {
      _rollback('Редактирование тайминга недоступно.');
      return;
    }
    emit(state.copyWith(isSaving: true, clearActionError: true));
    try {
      final payload = await (repository as TaskTimingRepository).updateEstimate(
        task.id,
        minutes,
        detail: state.detail,
      );
      _applyPayload(payload);
      await _reloadHistory(task.id);
    } on TaskDetailsException catch (error) {
      _rollback(error.message, task: task);
    } catch (_) {
      _rollback('Не удалось сохранить тайминг.', task: task);
    }
  }

  Future<void> timerAction(String action) async {
    final task = state.task;
    final repository = _repository;
    if (task == null || state.isSaving) return;
    if (repository is! TaskTimerRepository) {
      _rollback('Таймер недоступен.');
      return;
    }
    emit(state.copyWith(isSaving: true, clearActionError: true));
    try {
      final payload = await (repository as TaskTimerRepository).timerAction(
        task.id,
        action,
      );
      _applyPayload(payload);
      await _reloadHistory(task.id);
    } on TaskDetailsException catch (error) {
      _rollback(error.message, task: task);
    } catch (_) {
      _rollback('Не удалось сохранить таймер.', task: task);
    }
  }

  Future<List<TaskAssigneeModel>> getAssigneeCandidates() async {
    final task = state.task;
    final repository = _repository;
    if (task == null || repository is! TaskAssigneesRepository) {
      throw const TaskDetailsException(
        'Редактирование исполнителей недоступно.',
      );
    }
    return (repository as TaskAssigneesRepository).getAssigneeCandidates(
      task.projectId,
    );
  }

  Future<bool> updateAssignees(List<TaskAssigneeModel> assignees) async {
    final task = state.task;
    final repository = _repository;
    if (task == null ||
        state.isSaving ||
        repository is! TaskAssigneesRepository) {
      return false;
    }
    emit(state.copyWith(isSaving: true, clearActionError: true));
    try {
      final payload = await (repository as TaskAssigneesRepository)
          .updateAssignees(
            task.id,
            assignees.map((user) => user.userId).toList(),
          );
      _applyPayload(payload);
      await _reloadHistory(task.id);
      return true;
    } on TaskDetailsException catch (error) {
      _rollback(error.message, task: task);
      return false;
    } catch (_) {
      _rollback('Не удалось сохранить исполнителей.', task: task);
      return false;
    }
  }

  Future<void> load(String taskId, {ProjectTaskModel? initialTask}) async {
    final revision = ++_loadRevision;
    emit(
      state.copyWith(
        status: TaskDetailsStatus.loading,
        task: initialTask,
        clearError: true,
      ),
    );
    try {
      final payload = await _repository.getTask(taskId);
      if (isClosed || revision != _loadRevision) return;
      emit(
        state.copyWith(
          status: TaskDetailsStatus.success,
          task: payload.task,
          detail: payload.detail,
          resources: payload.resources,
          clearError: true,
        ),
      );
      await _loadSecondaryData(taskId, payload.task.projectId, revision);
    } on TaskDetailsException catch (error) {
      if (isClosed || revision != _loadRevision) return;
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
    final status = task.isDone ? reopenedTaskStatus(task, state.columns) : null;
    emit(
      state.copyWith(
        task: task.copyWith(progress: progress.toDouble(), status: status),
        isSaving: true,
        clearActionError: true,
      ),
    );
    try {
      final payload = await _repository.updateProgress(
        task.id,
        progress,
        status: status,
      );
      _applyPayload(payload);
    } on TaskDetailsException catch (error) {
      _rollback(error.message, task: oldTask);
    } catch (_) {
      _rollback('Не удалось обновить завершение задачи.', task: oldTask);
    }
  }

  Future<TaskLabelCatalog> getLabelCatalog() async {
    final repository = _repository;
    final task = state.task;
    if (task == null || repository is! TaskLabelCatalogRepository) {
      throw const TaskDetailsException('Каталог меток недоступен.');
    }
    return (repository as TaskLabelCatalogRepository).getLabelCatalog(task.id);
  }

  List<TaskLabelModel> labelsForScope(bool personal) {
    if (!personal) {
      return state.detail.labels.where((e) => !e.isPersonal).toList();
    }
    final raw = state.detail.raw['personalLabels'];
    final values = raw is Map ? raw[state.currentUser?.id] : null;
    return values is List
        ? values
              .whereType<Map>()
              .map((e) => TaskLabelModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : [];
  }

  Future<bool> saveScopedLabels(
    List<TaskLabelModel> labels, {
    required bool personal,
    required List<TaskLabelModel> catalog,
  }) async {
    final userId = state.currentUser?.id;
    if (personal && (userId == null || userId.isEmpty)) return false;
    final raw = Map<String, Object?>.from(state.detail.raw);
    if (personal) {
      for (final entry in {
        'personalLabels': labels,
        'personalLabelCatalog': catalog,
      }.entries) {
        final old = raw[entry.key];
        final map = old is Map
            ? Map<String, dynamic>.from(old)
            : <String, dynamic>{};
        map[userId!] = uniqueTaskLabels(
          entry.value,
        ).map((e) => e.toJson()).toList();
        raw[entry.key] = map;
      }
    } else {
      raw['labelCatalog'] = uniqueTaskLabels(
        catalog,
      ).map((e) => e.toJson()).toList();
    }
    final saved = await _saveDetail(
      state.detail.copyWith(
        raw: raw,
        labels: personal ? null : uniqueTaskLabels(labels),
      ),
    );
    if (saved) _notifyRelatedTasks();
    return saved;
  }

  void _notifyRelatedTasks() {
    // Other task consumers already subscribe to this invalidation signal.
    // Avoid reloading this editor while its acknowledged save is completing.
    assistantTaskChanges.removeListener(_onAiTasksChanged);
    notifyAssistantTaskChanges();
    if (!isClosed) assistantTaskChanges.addListener(_onAiTasksChanged);
  }

  Future<bool> updatePersonalLabels(List<TaskLabelModel> labels) {
    final userId = state.currentUser?.id;
    if (userId == null) return Future.value(false);
    final existing = state.detail.raw['personalLabels'];
    final personal = existing is Map
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};
    if (labels.isEmpty) {
      personal.remove(userId);
    } else {
      personal[userId] = labels.map((e) => e.toJson()).toList();
    }
    return _saveDetail(
      state.detail.copyWith(
        raw: {...state.detail.raw, 'personalLabels': personal},
      ),
    );
  }

  Future<bool> updateLabels(List<TaskLabelModel> labels) =>
      _saveDetail(state.detail.copyWith(labels: labels));
  Future<bool> addFiles(List<TaskFileModel> files) => _saveDetail(
    state.detail.copyWith(files: [...state.detail.files, ...files]),
  );
  Future<bool> removeFile(String id) {
    final raw = Map<String, Object?>.from(state.detail.raw);
    final cover = raw['cover'];
    if (cover is Map && cover['fileId'] == id) raw['cover'] = null;
    return _saveDetail(
      state.detail.copyWith(
        files: state.detail.files.where((file) => file.id != id).toList(),
        raw: raw,
      ),
    );
  }

  Future<List<TaskEpicModel>> getEpics() async {
    final repository = _repository;
    final task = state.task;
    if (repository is! TaskExtrasRepository ||
        task == null ||
        task.projectId.trim().isEmpty) {
      throw const TaskDetailsException('Загрузка эпиков недоступна.');
    }
    return (repository as TaskExtrasRepository).getEpics(task.projectId);
  }

  Future<bool> updateEpics(List<String> ids) async {
    final saved = await _extras((repository, task) async {
      final payload = await repository.updateEpics(
        task.id,
        ids.toSet().toList(),
      );
      _applyPayload(payload);
    });
    if (saved) _notifyRelatedTasks();
    return saved;
  }

  Future<bool> saveResource(
    TaskResourceModel resource, {
    required bool create,
  }) => _extras((repository, task) async {
    if (resource.name.trim().isEmpty ||
        resource.planValue < 0 ||
        resource.factValue < 0 ||
        !resource.planValue.isFinite ||
        !resource.factValue.isFinite) {
      throw const TaskDetailsException(
        'Укажите название и неотрицательные значения ресурса.',
      );
    }
    await repository.saveResource(task.id, resource, create: create);
    _applyPayload(await _repository.getTask(task.id));
  });
  Future<bool> deleteResource(String id) => _extras((repository, task) async {
    await repository.deleteResource(id);
    _applyPayload(await _repository.getTask(task.id));
  });

  Future<bool> createResourcePair() => _extras((repository, task) async {
    final creator = _repository;
    if (creator is! TaskResourceCreationRepository) {
      throw const TaskDetailsException('Создание пары ресурсов недоступно.');
    }
    final plan = await (creator as TaskResourceCreationRepository)
        .createResource(task.id, const TaskResourceModel(id: '', name: 'План'));
    TaskResourceModel? fact;
    try {
      fact = await (creator as TaskResourceCreationRepository).createResource(
        task.id,
        const TaskResourceModel(id: '', name: 'Факт'),
      );
    } catch (_) {
      await repository.deleteResource(plan.id);
      rethrow;
    } finally {
      try {
        _applyPayload(await _repository.getTask(task.id));
      } on TaskDetailsException {
        // An acknowledged creation must not become a failed create on GET failure.
        if (!isClosed && fact != null) {
          emit(state.copyWith(resources: [...state.resources, plan, fact]));
        }
      }
    }
  });

  Future<bool> deleteResourcePair(List<TaskResourceModel> pair) =>
      _extras((repository, task) async {
        try {
          for (final resource in pair) {
            await repository.deleteResource(resource.id);
          }
        } finally {
          _applyPayload(await _repository.getTask(task.id));
        }
      });

  Future<bool> patchResource(String id, Map<String, Object?> changes) =>
      _extras((_, task) async {
        final repository = _repository;
        if (repository is! TaskResourceOperationsRepository) {
          throw const TaskDetailsException('Изменение ресурса недоступно.');
        }
        await (repository as TaskResourceOperationsRepository).patchResource(
          id,
          changes,
        );
        _applyPayload(await _repository.getTask(task.id));
      });

  Future<Map<String, Object?>> resourceHistory(
    String id, {
    String? cursor,
  }) async {
    final repository = _repository;
    if (repository is! TaskResourceOperationsRepository) {
      throw const TaskDetailsException('История ресурса недоступна.');
    }
    return (repository as TaskResourceOperationsRepository).resourceHistory(
      id,
      cursor: cursor,
    );
  }

  Future<bool> _extras(
    Future<void> Function(TaskExtrasRepository, ProjectTaskModel) action,
  ) async {
    final repository = _repository;
    final task = state.task;
    if (repository is! TaskExtrasRepository || task == null || state.isSaving) {
      return false;
    }
    emit(state.copyWith(isSaving: true, clearActionError: true));
    try {
      await action(repository as TaskExtrasRepository, task);
      if (!isClosed) emit(state.copyWith(isSaving: false));
      await _reloadHistory(task.id);
      return true;
    } catch (e) {
      _rollback(
        e is TaskDetailsException
            ? e.message
            : 'Не удалось сохранить изменения.',
      );
      return false;
    }
  }

  Future<bool> updateTitle(String value) async {
    final task = state.task;
    final title = value.trim();
    if (task == null || state.isSaving || title.isEmpty) return false;
    if (title == task.title) return true;
    final repository = _repository;
    if (repository is! TaskTitleRepository) return false;
    emit(state.copyWith(isSaving: true, clearActionError: true));
    try {
      final payload = await (repository as TaskTitleRepository).updateTitle(
        task.id,
        title,
      );
      _applyPayload(payload);
      await _reloadHistory(task.id);
      return true;
    } on TaskDetailsException catch (error) {
      _rollback(error.message, task: task);
      return false;
    } catch (_) {
      _rollback('Не удалось изменить название задачи.', task: task);
      return false;
    }
  }

  Future<bool> updateLocation(Map<String, Object?>? location) => _saveDetail(
    state.detail.copyWith(raw: {...state.detail.raw, 'location': location}),
  );

  Future<bool> updateStart(DateTime? start) =>
      _advancedUpdate((r, task) => r.updateStart(task.id, start));

  Future<bool> updateDates(DateTime? start, DateTime? end) =>
      _extras((_, task) async {
        if (start != null && end != null && start.isAfter(end)) {
          throw const TaskDetailsException('Начало не может быть позже срока.');
        }
        final repository = _repository;
        if (repository is! TaskDatesRepository) {
          throw const TaskDetailsException('Редактирование дат недоступно.');
        }
        _applyPayload(
          await (repository as TaskDatesRepository).updateDates(
            task.id,
            start,
            end,
          ),
        );
      });
  Future<bool> updateDependencies(List<String> ids) =>
      _advancedUpdate((r, task) => r.updateDependencies(task.id, ids));
  Future<bool> _advancedUpdate(
    Future<TaskDetailsPayload> Function(
      TaskAdvancedRepository,
      ProjectTaskModel,
    )
    request,
  ) async {
    final task = state.task;
    final repository = _repository;
    if (task == null ||
        state.isSaving ||
        repository is! TaskAdvancedRepository) {
      return false;
    }
    emit(state.copyWith(isSaving: true, clearActionError: true));
    try {
      final payload = await request(repository as TaskAdvancedRepository, task);
      _applyPayload(payload);
      await _reloadHistory(task.id);
      return true;
    } catch (e) {
      _rollback(
        e is TaskDetailsException ? e.message : 'Не удалось сохранить задачу.',
      );
      return false;
    }
  }

  Future<bool> updateDescription(String description) async {
    final updated = state.detail.copyWith(description: description.trim());
    return _saveDetail(updated);
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

  Future<void> addChecklist({String name = 'Новый чек-лист'}) async {
    if (state.isSaving) return;
    await _saveDetail(
      state.detail.copyWith(
        checklists: [
          ...state.detail.checklists,
          TaskChecklistModel(
            id: 'checklist_${DateTime.now().microsecondsSinceEpoch}_mobile',
            name: name.trim().isEmpty ? 'Новый чек-лист' : name.trim(),
          ),
        ],
      ),
    );
  }

  Future<void> modifyChecklist(
    String id,
    TaskChecklistModel Function(TaskChecklistModel) change,
  ) async {
    if (state.isSaving ||
        !state.detail.checklists.any((list) => list.id == id)) {
      return;
    }
    await _saveDetail(
      state.detail.copyWith(
        checklists: [
          for (final list in state.detail.checklists)
            list.id == id ? change(list) : list,
        ],
      ),
    );
  }

  Future<void> deleteChecklist(String id) async {
    if (state.isSaving) return;
    await _saveDetail(
      state.detail.copyWith(
        checklists: state.detail.checklists
            .where((list) => list.id != id)
            .toList(),
      ),
    );
  }

  Future<void> moveChecklist(String id, int direction) async {
    if (state.isSaving) return;
    final lists = [...state.detail.checklists];
    final index = lists.indexWhere((list) => list.id == id);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= lists.length) return;
    lists.insert(target, lists.removeAt(index));
    await _saveDetail(state.detail.copyWith(checklists: lists));
  }

  Future<bool> addComment(
    String text, {
    List<TaskFileModel> files = const [],
  }) async {
    final value = text.trim();
    if ((value.isEmpty && files.isEmpty) ||
        files.length > 10 ||
        state.isSaving ||
        state.task == null) {
      return false;
    }
    final repository = _repository;
    if (repository is TaskAdvancedRepository) {
      final task = state.task!;
      emit(state.copyWith(isSaving: true, clearActionError: true));
      try {
        final comment = await (repository as TaskAdvancedRepository)
            .postComment(task.id, value, files);
        if (isClosed) return false;
        emit(
          state.copyWith(
            task: state.task?.copyWith(
              commentCount: state.detail.comments.length + 1,
            ),
            detail: state.detail.copyWith(
              comments: [...state.detail.comments, comment],
            ),
            isSaving: false,
          ),
        );
        await _reloadHistory(task.id);
        return true;
      } catch (e) {
        _rollback(
          e is TaskDetailsException
              ? e.message
              : 'Не удалось отправить комментарий.',
        );
        return false;
      }
    }
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
      raw: {
        if (files.isNotEmpty) 'files': files.map((f) => f.toJson()).toList(),
      },
    );
    return _saveDetail(
      state.detail.copyWith(
        comments: <TaskCommentModel>[...state.detail.comments, comment],
      ),
    );
  }

  Future<void> _loadSecondaryData(
    String taskId,
    String projectId,
    int revision,
  ) async {
    try {
      final columns = await _repository.getColumns(projectId);
      if (!isClosed && revision == _loadRevision) {
        emit(state.copyWith(columns: columns));
      }
    } on TaskDetailsException {
      // Built-in status labels remain available when columns cannot be loaded.
    }
    try {
      final history = await _repository.getHistory(taskId);
      if (!isClosed && revision == _loadRevision) {
        emit(state.copyWith(history: history));
      }
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

  Future<bool> _saveDetail(TaskDetailModel updated) async {
    final task = state.task;
    if (task == null || state.isSaving) return false;
    final oldDetail = state.detail;
    emit(
      state.copyWith(detail: updated, isSaving: true, clearActionError: true),
    );
    try {
      final payload = await _repository.updateDetail(task.id, updated);
      _applyPayload(payload);
      await _reloadHistory(task.id);
      return true;
    } on TaskDetailsException catch (error) {
      _rollback(error.message, detail: oldDetail);
      return false;
    } catch (_) {
      _rollback('Не удалось сохранить изменения задачи.', detail: oldDetail);
      return false;
    }
  }

  Future<void> _reloadHistory(String taskId) async {
    try {
      final history = await _repository.getHistory(taskId);
      if (!isClosed && state.task?.id == taskId) {
        emit(state.copyWith(history: history));
      }
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
