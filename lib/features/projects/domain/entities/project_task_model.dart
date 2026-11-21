import 'package:equatable/equatable.dart';
import '../../../tasks/domain/entities/task_label_model.dart';
import 'task_assignee_model.dart';
import 'task_epic_model.dart';
import 'project_task_cover.dart';
import 'project_task_detail_snapshot.dart';

class ProjectTaskModel extends Equatable {
  const ProjectTaskModel({
    required this.id,
    required this.projectId,
    required this.status,
    this.displayId = '',
    this.deps = const [],
    this.title = '',
    this.progress,
    this.priority = 'MED',
    this.detail,
    this.start,
    this.end,
    this.order = 0,
    this.estimate = 0,
    this.timerStartedAt,
    this.timerElapsedMs = 0,
    this.isTimingEnabled = true,
    this.archived = false,
    this.commentCount = 0,
    this.fileCount = 0,
    this.resourceCount = 0,
    this.checklistCompleted = 0,
    this.checklistTotal = 0,
    this.assignees = const <TaskAssigneeModel>[],
    this.epics = const <TaskEpicModel>[],
    this.labels = const <TaskLabelModel>[],
  });

  final String id;
  final String displayId;
  final String title;
  final String projectId;
  final String status;
  final double? progress;
  final String priority;
  final ProjectTaskDetailSnapshot? detail;
  final List<String> deps;
  final DateTime? start;
  final DateTime? end;
  final int order;
  final double estimate;
  final DateTime? timerStartedAt;
  final int timerElapsedMs;
  final bool isTimingEnabled;
  final bool archived;
  final int commentCount;
  final int fileCount;
  final int resourceCount;

  final int checklistCompleted;
  final int checklistTotal;
  final List<TaskAssigneeModel> assignees;
  final List<TaskEpicModel> epics;
  final List<TaskLabelModel> labels;

  bool get isDone => status.toUpperCase() == 'DONE' || (progress ?? 0) >= 100;

  List<String> get epicNames => epics
      .map((item) => item.name.trim())
      .where((name) => name.isNotEmpty)
      .toList(growable: false);

  ProjectTaskCover? get cover => detail?.cover;

  List<TaskLabelModel> labelsForUser(String? userId) {
    if (userId == null) return labels;
    final values = detail?.personalLabelsByUser[userId];
    if (values == null) return labels;
    return [
      ...labels.where((label) => !label.isPersonal),
      ...values.map((label) => label.copyWith(isPersonal: true)),
    ];
  }

  ProjectTaskModel copyWith({
    String? id,
    String? displayId,
    String? title,
    String? projectId,
    String? status,
    double? progress,
    String? priority,
    ProjectTaskDetailSnapshot? detail,
    List<String>? deps,
    DateTime? start,
    DateTime? end,
    int? order,
    double? estimate,
    DateTime? timerStartedAt,
    int? timerElapsedMs,
    bool? isTimingEnabled,
    bool? archived,
    int? commentCount,
    int? fileCount,
    int? resourceCount,
    int? checklistCompleted,
    int? checklistTotal,
    List<TaskAssigneeModel>? assignees,
    List<TaskEpicModel>? epics,
    List<TaskLabelModel>? labels,
  }) {
    return ProjectTaskModel(
      id: id ?? this.id,
      displayId: displayId ?? this.displayId,
      title: title ?? this.title,
      projectId: projectId ?? this.projectId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      priority: priority ?? this.priority,
      detail: detail ?? this.detail,
      deps: deps ?? this.deps,
      start: start ?? this.start,
      end: end ?? this.end,
      order: order ?? this.order,
      estimate: estimate ?? this.estimate,
      timerStartedAt: timerStartedAt ?? this.timerStartedAt,
      timerElapsedMs: timerElapsedMs ?? this.timerElapsedMs,
      isTimingEnabled: isTimingEnabled ?? this.isTimingEnabled,
      archived: archived ?? this.archived,
      commentCount: commentCount ?? this.commentCount,
      fileCount: fileCount ?? this.fileCount,
      resourceCount: resourceCount ?? this.resourceCount,
      checklistCompleted: checklistCompleted ?? this.checklistCompleted,
      checklistTotal: checklistTotal ?? this.checklistTotal,
      assignees: assignees ?? this.assignees,
      epics: epics ?? this.epics,
      labels: labels ?? this.labels,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    displayId,
    title,
    projectId,
    status,
    progress,
    priority,
    detail,
    deps,
    start,
    end,
    order,
    estimate,
    timerStartedAt,
    timerElapsedMs,
    isTimingEnabled,
    archived,
    commentCount,
    fileCount,
    resourceCount,
    checklistCompleted,
    checklistTotal,
    assignees,
    epics,
    labels,
  ];
}
