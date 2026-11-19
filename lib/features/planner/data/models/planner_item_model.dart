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
    this.plannedDate,
    this.durationMinutes = 30,
    this.completed = false,
    this.archived = false,
    this.task,
    this.external = false,
    this.allDay = false,
  });

  factory PlannerItemModel.fromJson(Map<String, dynamic> json) {
    final taskJson = json['task'];
    final inbox = json['inboxTask'];
    final project = json['project'];
    final task = taskJson is Map
        ? ProjectTaskModel.fromJson(Map<String, dynamic>.from(taskJson))
        : null;
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
      plannedDate: _readDay(json['plannedDate']),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      // A linked task supplies context, not the lifecycle of this day's entry.
      completed: json['completed'] == true,
      archived: json['archived'] == true,
      task: task,
      external: json['external'] == true,
      allDay: json['allDay'] == true,
    );
  }

  final String id, title, projectName;
  final String? projectId, taskId, inboxTaskId;
  final DateTime? scheduledAt;

  /// Calendar date without a timezone; never an execution time at midnight.
  final DateTime? plannedDate;
  DateTime? get day {
    final local = scheduledAt?.toLocal();
    return local == null
        ? plannedDate
        : DateTime(local.year, local.month, local.day);
  }

  static DateTime? _readDay(Object? value) {
    final text = value?.toString() ?? '';
    if (text.length < 10) return null;
    final parsed = DateTime.tryParse(text.substring(0, 10));
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  final int durationMinutes;
  final bool completed, archived;
  final bool external, allDay;
  final ProjectTaskModel? task;
  bool get isStandalone => taskId == null && inboxTaskId == null;
  String get displayTitle {
    if (taskId == null) return title;
    final displayId = task?.displayId.trim() ?? '';
    final identifier = displayId.isNotEmpty ? displayId : taskId!.trim();
    return identifier.isEmpty ? title : '$identifier $title';
  }

  Map<String, dynamic> toJson() => {
    'external': external,
    'allDay': allDay,
    'id': id,
    'title': title,
    'projectId': projectId,
    'taskId': taskId,
    'inboxTaskId': inboxTaskId,
    'project': {'name': projectName},
    'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
    'plannedDate': plannedDate == null
        ? null
        : '${plannedDate!.year.toString().padLeft(4, '0')}-${plannedDate!.month.toString().padLeft(2, '0')}-${plannedDate!.day.toString().padLeft(2, '0')}',
    'durationMinutes': durationMinutes,
    'completed': completed,
    'archived': archived,
    if (task != null) 'task': task!.toJson(),
    if (inboxTaskId != null) 'inboxTask': {'id': inboxTaskId, 'title': title},
  };

  PlannerItemModel copyWith({
    String? id,
    String? title,
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    String? projectName,
    Object? scheduledAt = _unchanged,
    Object? plannedDate = _unchanged,
    int? durationMinutes,
    bool? completed,
    bool? archived,
    ProjectTaskModel? task,
    bool? external,
    bool? allDay,
  }) => PlannerItemModel(
    id: id ?? this.id,
    title: title ?? this.title,
    projectId: projectId ?? this.projectId,
    taskId: taskId ?? this.taskId,
    inboxTaskId: inboxTaskId ?? this.inboxTaskId,
    projectName: projectName ?? this.projectName,
    scheduledAt: identical(scheduledAt, _unchanged)
        ? this.scheduledAt
        : scheduledAt as DateTime?,
    plannedDate: identical(plannedDate, _unchanged)
        ? this.plannedDate
        : plannedDate as DateTime?,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    completed: completed ?? this.completed,
    archived: archived ?? this.archived,
    task: task ?? this.task,
    external: external ?? this.external,
    allDay: allDay ?? this.allDay,
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
    plannedDate,
    durationMinutes,
    completed,
    archived,
    external,
    allDay,
    task,
  ];
  static const _unchanged = Object();
}
