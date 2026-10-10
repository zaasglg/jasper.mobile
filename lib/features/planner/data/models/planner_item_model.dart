import 'package:equatable/equatable.dart';
import '../../../projects/data/models/project_task_model.dart';

class PlannerItemModel extends Equatable {
  const PlannerItemModel({
    required this.id,
    required this.title,
    this.projectId,
    this.taskId,
    this.inboxTaskId,
    this.projectName = 'Ежедневник',
    this.scheduledAt,
    this.durationMinutes = 30,
    this.completed = false,
    this.archived = false,
    this.task,
  });

  factory PlannerItemModel.fromJson(Map<String, dynamic> json) {
    final taskJson = json['task'];
    final inbox = json['inboxTask'];
    final project = json['project'];
    final task = taskJson is Map
        ? ProjectTaskModel.fromJson(Map<String, dynamic>.from(taskJson))
        : null;
    final inboxDetail = inbox is Map ? inbox['detail'] : null;
    return PlannerItemModel(
      id: json['id']?.toString() ?? '',
      title:
          task?.title ??
          (inbox is Map ? inbox['title']?.toString() : null) ??
          json['title']?.toString() ??
          'Без названия',
      projectId: json['projectId']?.toString(),
      taskId: json['taskId']?.toString() ?? task?.id,
      inboxTaskId: json['inboxTaskId']?.toString(),
      projectName: inbox is Map
          ? 'Инбокс'
          : project is Map
          ? project['name']?.toString() ?? 'Проект'
          : 'Ежедневник',
      scheduledAt: DateTime.tryParse(json['scheduledAt']?.toString() ?? ''),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      completed:
          task?.isDone ??
          (inbox is Map
              ? inbox['completed'] == true ||
                    (inboxDetail is Map && inboxDetail['completed'] == true)
              : json['completed'] == true),
      archived:
          json['archived'] == true ||
          task?.archived == true ||
          (inbox is Map && inbox['archived'] == true),
      task: task,
    );
  }

  final String id, title, projectName;
  final String? projectId, taskId, inboxTaskId;
  final DateTime? scheduledAt;
  final int durationMinutes;
  final bool completed, archived;
  final ProjectTaskModel? task;
  bool get isStandalone => taskId == null && inboxTaskId == null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'projectId': projectId,
    'taskId': taskId,
    'inboxTaskId': inboxTaskId,
    'project': {'name': projectName},
    'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
    'durationMinutes': durationMinutes,
    'completed': completed,
    'archived': archived,
    if (task != null) 'task': task!.toJson(),
    if (inboxTaskId != null)
      'inboxTask': {
        'id': inboxTaskId,
        'title': title,
        'completed': completed,
        'archived': archived,
      },
  };

  PlannerItemModel copyWith({
    String? id,
    String? title,
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    String? projectName,
    DateTime? scheduledAt,
    int? durationMinutes,
    bool? completed,
    bool? archived,
    ProjectTaskModel? task,
  }) => PlannerItemModel(
    id: id ?? this.id,
    title: title ?? this.title,
    projectId: projectId ?? this.projectId,
    taskId: taskId ?? this.taskId,
    inboxTaskId: inboxTaskId ?? this.inboxTaskId,
    projectName: projectName ?? this.projectName,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    completed: completed ?? this.completed,
    archived: archived ?? this.archived,
    task: task ?? this.task,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    projectId,
    taskId,
    inboxTaskId,
    projectName,
    scheduledAt,
    durationMinutes,
    completed,
    archived,
    task,
  ];
}
