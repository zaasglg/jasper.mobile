import 'package:equatable/equatable.dart';

import '../../../projects/data/models/project_model.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../data/models/kanban_column_model.dart';
import '../../domain/entities/task_extra_field.dart';

enum MyTasksStatus { initial, loading, success, failure }

class MyTasksState extends Equatable {
  const MyTasksState({
    this.status = MyTasksStatus.initial,
    this.projects = const <ProjectModel>[],
    this.tasks = const <ProjectTaskModel>[],
    this.columnsByProjectId = const <String, List<KanbanColumnModel>>{},
    this.selectedProjectIds = const <String>{},
    this.selectedScopeProjectIds = const <String>{},
    this.visibleFields = const <TaskExtraField>{
      TaskExtraField.id,
      TaskExtraField.column,
      TaskExtraField.epics,
    },
    this.sortAscending = true,
    this.updatingTaskIds = const <String>{},
    this.errorMessage,
    this.actionErrorMessage,
    this.actionRevision = 0,
  });

  final MyTasksStatus status;
  final List<ProjectModel> projects;
  final List<ProjectTaskModel> tasks;
  final Map<String, List<KanbanColumnModel>> columnsByProjectId;
  final Set<String> selectedProjectIds;
  final Set<String> selectedScopeProjectIds;
  final Set<TaskExtraField> visibleFields;
  final bool sortAscending;
  final Set<String> updatingTaskIds;
  final String? errorMessage;
  final String? actionErrorMessage;
  final int actionRevision;

  String columnName(ProjectTaskModel task) {
    final normalizedStatus = task.status.toUpperCase();
    for (final column
        in columnsByProjectId[task.projectId] ?? const <KanbanColumnModel>[]) {
      if (column.statusMap.toUpperCase() == normalizedStatus &&
          column.name.trim().isNotEmpty) {
        return column.name.trim();
      }
    }
    return switch (normalizedStatus) {
      'BACKLOG' => 'Очередь',
      'TODO' => 'К работе',
      'PROGRESS' || 'IN_PROGRESS' => 'В работе',
      'REVIEW' => 'На проверке',
      'DONE' => 'Готово',
      _ => '—',
    };
  }

  MyTasksState copyWith({
    MyTasksStatus? status,
    List<ProjectModel>? projects,
    List<ProjectTaskModel>? tasks,
    Map<String, List<KanbanColumnModel>>? columnsByProjectId,
    Set<String>? selectedProjectIds,
    Set<String>? selectedScopeProjectIds,
    Set<TaskExtraField>? visibleFields,
    bool? sortAscending,
    Set<String>? updatingTaskIds,
    String? errorMessage,
    bool clearError = false,
    String? actionErrorMessage,
    bool clearActionError = false,
    int? actionRevision,
  }) {
    return MyTasksState(
      status: status ?? this.status,
      projects: projects ?? this.projects,
      tasks: tasks ?? this.tasks,
      columnsByProjectId: columnsByProjectId ?? this.columnsByProjectId,
      selectedProjectIds: selectedProjectIds ?? this.selectedProjectIds,
      selectedScopeProjectIds:
          selectedScopeProjectIds ?? this.selectedScopeProjectIds,
      visibleFields: visibleFields ?? this.visibleFields,
      sortAscending: sortAscending ?? this.sortAscending,
      updatingTaskIds: updatingTaskIds ?? this.updatingTaskIds,
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
    projects,
    tasks,
    columnsByProjectId,
    selectedProjectIds,
    selectedScopeProjectIds,
    visibleFields,
    sortAscending,
    updatingTaskIds,
    errorMessage,
    actionErrorMessage,
    actionRevision,
  ];
}
