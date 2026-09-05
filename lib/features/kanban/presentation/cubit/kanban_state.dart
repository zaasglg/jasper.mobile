import 'package:equatable/equatable.dart';

import '../../../projects/data/models/project_task_model.dart';
import '../../../tasks/data/models/kanban_column_model.dart';
import '../../domain/utils/kanban_utils.dart';

enum KanbanStatus { initial, loading, success, failure }

class KanbanState extends Equatable {
  const KanbanState({
    this.status = KanbanStatus.initial,
    this.projectId = '',
    this.columns = const <KanbanColumnModel>[],
    this.tasks = const <ProjectTaskModel>[],
    this.search = '',
    this.priorityFilter,
    this.movingTaskIds = const <String>{},
    this.errorMessage,
    this.actionErrorMessage,
    this.actionRevision = 0,
  });

  final KanbanStatus status;
  final String projectId;
  final List<KanbanColumnModel> columns;
  final List<ProjectTaskModel> tasks;
  final String search;
  final String? priorityFilter;
  final Set<String> movingTaskIds;
  final String? errorMessage;
  final String? actionErrorMessage;
  final int actionRevision;

  List<ProjectTaskModel> tasksFor(KanbanColumnModel column) {
    final query = search.trim().toLowerCase();
    final grouped = groupKanbanTasks(columns, tasks);
    final values =
        grouped[column.statusMap.toUpperCase()] ?? const <ProjectTaskModel>[];
    return values
        .where(
          (task) =>
              (query.isEmpty ||
                  task.title.toLowerCase().contains(query) ||
                  task.displayId.toLowerCase().contains(query)) &&
              (priorityFilter == null ||
                  task.priority.toUpperCase() == priorityFilter),
        )
        .toList(growable: false);
  }

  bool exceedsWip(KanbanColumnModel column) {
    final limit = column.wip;
    return limit != null && tasksFor(column).length > limit;
  }

  KanbanState copyWith({
    KanbanStatus? status,
    String? projectId,
    List<KanbanColumnModel>? columns,
    List<ProjectTaskModel>? tasks,
    String? search,
    String? priorityFilter,
    bool clearPriorityFilter = false,
    Set<String>? movingTaskIds,
    String? errorMessage,
    bool clearError = false,
    String? actionErrorMessage,
    bool clearActionError = false,
    int? actionRevision,
  }) {
    return KanbanState(
      status: status ?? this.status,
      projectId: projectId ?? this.projectId,
      columns: columns ?? this.columns,
      tasks: tasks ?? this.tasks,
      search: search ?? this.search,
      priorityFilter: clearPriorityFilter
          ? null
          : priorityFilter ?? this.priorityFilter,
      movingTaskIds: movingTaskIds ?? this.movingTaskIds,
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
    projectId,
    columns,
    tasks,
    search,
    priorityFilter,
    movingTaskIds,
    errorMessage,
    actionErrorMessage,
    actionRevision,
  ];
}
