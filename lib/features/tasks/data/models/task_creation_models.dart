import 'package:equatable/equatable.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/data/models/user_profile_dto.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../../workspaces/data/models/workspace_model.dart';
import 'kanban_column_model.dart';
import 'task_detail_model.dart';

class TaskCreationCatalog extends Equatable {
  const TaskCreationCatalog({required this.workspaces, required this.user});
  final List<WorkspaceModel> workspaces;
  final UserProfile user;
  factory TaskCreationCatalog.fromJson(Map<String, dynamic> json) =>
      TaskCreationCatalog(
        workspaces: (json['workspaces'] as List? ?? [])
            .whereType<Map>()
            .map((e) => WorkspaceModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        user: UserProfileDto.fromJson(
          Map<String, dynamic>.from(json['user'] as Map),
        ).toEntity(),
      );
  Map<String, dynamic> toJson() => {
    'workspaces': workspaces.map((e) => e.toJson()).toList(),
    'user': UserProfileDto.fromEntity(user).toJson(),
  };
  TaskCreationCatalog copyWith({
    List<WorkspaceModel>? workspaces,
    UserProfile? user,
  }) => TaskCreationCatalog(
    workspaces: workspaces ?? this.workspaces,
    user: user ?? this.user,
  );
  @override
  List<Object?> get props => [workspaces, user];
}

class TaskCreationOptions extends Equatable {
  const TaskCreationOptions({
    this.columns = const [],
    this.epics = const [],
    this.members = const [],
    this.tasks = const [],
  });
  final List<KanbanColumnModel> columns;
  final List<TaskEpicModel> epics;
  final List<TaskAssigneeModel> members;
  final List<ProjectTaskModel> tasks;
  factory TaskCreationOptions.fromJson(
    Map<String, dynamic> json,
  ) => TaskCreationOptions(
    columns: (json['columns'] as List? ?? [])
        .whereType<Map>()
        .map((e) => KanbanColumnModel.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    epics: (json['epics'] as List? ?? [])
        .whereType<Map>()
        .map((e) => TaskEpicModel.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    members: (json['members'] as List? ?? [])
        .whereType<Map>()
        .map((e) => TaskAssigneeModel.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    tasks: (json['tasks'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ProjectTaskModel.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'columns': columns.map((e) => e.toJson()).toList(),
    'epics': epics.map((e) => e.toJson()).toList(),
    'members': members.map((e) => e.toJson()).toList(),
    'tasks': tasks.map((e) => e.toJson()).toList(),
  };
  TaskCreationOptions copyWith({
    List<KanbanColumnModel>? columns,
    List<TaskEpicModel>? epics,
    List<TaskAssigneeModel>? members,
    List<ProjectTaskModel>? tasks,
  }) => TaskCreationOptions(
    columns: columns ?? this.columns,
    epics: epics ?? this.epics,
    members: members ?? this.members,
    tasks: tasks ?? this.tasks,
  );
  @override
  List<Object?> get props => [columns, epics, members, tasks];
}

class TaskCreationRequest extends Equatable {
  const TaskCreationRequest({
    required this.workspaceId,
    required this.projectId,
    required this.title,
    required this.status,
    this.priority = 'MED',
    this.end,
    this.estimateMinutes = 0,
    this.epicIds = const [],
    this.assigneeIds = const [],
    this.files = const [],
    this.position = 1,
  });
  final String workspaceId, projectId, title, status, priority;
  final DateTime? end;
  final int estimateMinutes, position;
  final List<String> epicIds, assigneeIds;
  final List<TaskFileModel> files;
  factory TaskCreationRequest.fromJson(Map<String, dynamic> json) {
    final detail = json['detail'] is Map
        ? Map<String, dynamic>.from(json['detail'] as Map)
        : <String, dynamic>{};
    return TaskCreationRequest(
      workspaceId: json['workspaceId']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'MED',
      end: DateTime.tryParse(json['end']?.toString() ?? ''),
      estimateMinutes: (detail['estimateMinutes'] as num?)?.toInt() ?? 0,
      position: (json['order'] as num?)?.toInt() ?? 1,
      epicIds: (json['epicIds'] as List? ?? []).cast<String>(),
      assigneeIds: (json['assigneeIds'] as List? ?? []).cast<String>(),
      files: (detail['files'] as List? ?? [])
          .whereType<Map>()
          .map((e) => TaskFileModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
  Map<String, dynamic> toJson() => {
    'workspaceId': workspaceId,
    'projectId': projectId,
    'title': title.trim(),
    'status': status,
    'priority': priority,
    'order': position,
    'progress': 0,
    'epicIds': epicIds,
    'assigneeIds': assigneeIds,
    'deps': <String>[],
    'est': (estimateMinutes / 60).ceil(),
    if (end != null) 'end': end!.toUtc().toIso8601String(),
    'detail': TaskDetailModel(
      files: files,
      estimateMinutes: estimateMinutes,
    ).toJson(),
  };
  TaskCreationRequest copyWith({
    String? workspaceId,
    String? projectId,
    String? title,
    String? status,
    String? priority,
    DateTime? end,
    bool clearEnd = false,
    int? estimateMinutes,
    int? position,
    List<String>? epicIds,
    List<String>? assigneeIds,
    List<TaskFileModel>? files,
  }) => TaskCreationRequest(
    workspaceId: workspaceId ?? this.workspaceId,
    projectId: projectId ?? this.projectId,
    title: title ?? this.title,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    end: clearEnd ? null : end ?? this.end,
    estimateMinutes: estimateMinutes ?? this.estimateMinutes,
    position: position ?? this.position,
    epicIds: epicIds ?? this.epicIds,
    assigneeIds: assigneeIds ?? this.assigneeIds,
    files: files ?? this.files,
  );
  @override
  List<Object?> get props => [
    workspaceId,
    projectId,
    title,
    status,
    priority,
    end,
    estimateMinutes,
    position,
    epicIds,
    assigneeIds,
    files,
  ];
}

class TaskCreationResult extends Equatable {
  const TaskCreationResult({
    required this.task,
    required this.workspaceId,
    this.orderWarning = false,
  });
  final ProjectTaskModel task;
  final String workspaceId;
  final bool orderWarning;
  factory TaskCreationResult.fromJson(Map<String, dynamic> json) =>
      TaskCreationResult(
        task: ProjectTaskModel.fromJson(
          Map<String, dynamic>.from(json['task'] as Map),
        ),
        workspaceId: json['workspaceId']?.toString() ?? '',
        orderWarning: json['orderWarning'] == true,
      );
  Map<String, dynamic> toJson() => {
    'task': task.toJson(),
    'workspaceId': workspaceId,
    'orderWarning': orderWarning,
  };
  TaskCreationResult copyWith({
    ProjectTaskModel? task,
    String? workspaceId,
    bool? orderWarning,
  }) => TaskCreationResult(
    task: task ?? this.task,
    workspaceId: workspaceId ?? this.workspaceId,
    orderWarning: orderWarning ?? this.orderWarning,
  );
  @override
  List<Object?> get props => [task, workspaceId, orderWarning];
}
