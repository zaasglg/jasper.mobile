import 'package:equatable/equatable.dart';

import '../../../profile/data/models/user_profile.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../data/models/task_detail_model.dart';
import '../../data/models/kanban_column_model.dart';

enum TaskDetailsStatus { initial, loading, success, failure }

class TaskDetailsState extends Equatable {
  const TaskDetailsState({
    this.status = TaskDetailsStatus.initial,
    this.task,
    this.detail = const TaskDetailModel(),
    this.resources = const <TaskResourceModel>[],
    this.history = const <TaskHistoryEntryModel>[],
    this.columns = const <KanbanColumnModel>[],
    this.currentUser,
    this.isSaving = false,
    this.errorMessage,
    this.actionErrorMessage,
    this.actionRevision = 0,
  });

  final TaskDetailsStatus status;
  final ProjectTaskModel? task;
  final TaskDetailModel detail;
  final List<TaskResourceModel> resources;
  final List<TaskHistoryEntryModel> history;
  final List<KanbanColumnModel> columns;
  final UserProfile? currentUser;
  final bool isSaving;
  final String? errorMessage;
  final String? actionErrorMessage;
  final int actionRevision;

  TaskDetailsState copyWith({
    TaskDetailsStatus? status,
    ProjectTaskModel? task,
    TaskDetailModel? detail,
    List<TaskResourceModel>? resources,
    List<TaskHistoryEntryModel>? history,
    List<KanbanColumnModel>? columns,
    UserProfile? currentUser,
    bool? isSaving,
    String? errorMessage,
    String? actionErrorMessage,
    bool clearError = false,
    bool clearActionError = false,
    int? actionRevision,
  }) {
    return TaskDetailsState(
      status: status ?? this.status,
      task: task ?? this.task,
      detail: detail ?? this.detail,
      resources: resources ?? this.resources,
      history: history ?? this.history,
      columns: columns ?? this.columns,
      currentUser: currentUser ?? this.currentUser,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      actionErrorMessage: clearActionError
          ? null
          : actionErrorMessage ?? this.actionErrorMessage,
      actionRevision: actionRevision ?? this.actionRevision,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    task,
    detail,
    resources,
    history,
    columns,
    currentUser,
    isSaving,
    errorMessage,
    actionErrorMessage,
    actionRevision,
  ];
}
