import 'dart:convert';
import '../../../tasks/data/models/task_detail_model.dart';
import '../../../projects/domain/entities/project_task_model.dart';
import '../../../projects/data/models/project_task_dto.dart';
import 'package:equatable/equatable.dart';

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
    this.icon,
    this.creatorName,
    this.reminderMinutes = 0,
    this.checklists = const [],
    this.detail = const {},
  });

  factory PlannerItemModel.fromJson(Map<String, dynamic> json) {
    final rawDetail = json['detail'];
    Object? decoded = rawDetail;
    if (rawDetail is String) {
      try {
        decoded = jsonDecode(rawDetail);
      } catch (_) {
        decoded = null;
      }
    }
    final detail = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    final creator = json['creator'];
    final taskJson = json['task'];
    final inbox = json['inboxTask'];
    final project = json['project'];
    final task = taskJson is Map
        ? ProjectTaskDto.fromJson(
            Map<String, dynamic>.from(taskJson),
          ).toEntity()
        : null;
    final scheduled = DateTime.tryParse(json['scheduledAt']?.toString() ?? '');
    final hasTime = json['hasTime'] != false;
    final local = scheduled?.toLocal();
    final plannedDay =
        _readDay(json['plannedDate']) ??
        (!hasTime && local != null
            ? DateTime(local.year, local.month, local.day)
            : null);
    return PlannerItemModel(
      creatorName: creator is Map ? creator['name']?.toString() : null,
      reminderMinutes: json['reminderMinutes'] is num
          ? (json['reminderMinutes'] as num).toInt().clamp(0, 10080)
          : 0,
      detail: detail,
      checklists: TaskDetailModel.fromJson(detail).checklists,

      icon: json['icon'] is String && (json['icon'] as String).trim().isNotEmpty
          ? (json['icon'] as String).trim().toLowerCase()
          : null,
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
      scheduledAt: hasTime ? scheduled : null,
      plannedDate: plannedDay,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      // Match the web's source of truth when planner entries link tasks.
      completed: task != null
          ? task.isDone
          : inbox is Map
          ? inbox['detail'] is Map &&
                (inbox['detail'] as Map)['completed'] == true
          : json['completed'] == true,
      archived: json['archived'] == true,
      task: task,
      external: json['external'] == true,
      allDay: json['allDay'] == true,
    );
  }

  final String id, title, projectName;
  final String? projectId, taskId, inboxTaskId;
  final String? icon, creatorName;
  final int reminderMinutes;
  final List<TaskChecklistModel> checklists;
  final Map<String, dynamic> detail;
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
    if (icon != null) 'icon': icon,
    if (creatorName != null) 'creator': {'name': creatorName},
    'reminderMinutes': reminderMinutes,
    'detail': {
      ...detail,
      if (checklists.isNotEmpty || detail.containsKey('checklists'))
        'checklists': checklists.map((list) => list.toJson()).toList(),
    },
    'external': external,
    'allDay': allDay,
    'id': id,
    'title': title,
    'projectId': projectId,
    'taskId': taskId,
    'inboxTaskId': inboxTaskId,
    'project': {'name': projectName},
    'hasTime': scheduledAt != null,
    'scheduledAt':
        (scheduledAt ??
                (plannedDate == null
                    ? null
                    : DateTime(
                        plannedDate!.year,
                        plannedDate!.month,
                        plannedDate!.day,
                      )))
            ?.toUtc()
            .toIso8601String(),
    'plannedDate': plannedDate == null
        ? null
        : '${plannedDate!.year.toString().padLeft(4, '0')}-${plannedDate!.month.toString().padLeft(2, '0')}-${plannedDate!.day.toString().padLeft(2, '0')}',
    'durationMinutes': durationMinutes,
    'completed': completed,
    'archived': archived,
    if (task != null) 'task': ProjectTaskDto.fromEntity(task!).toJson(),
    if (inboxTaskId != null)
      'inboxTask': {
        'id': inboxTaskId,
        'title': title,
        'detail': {'completed': completed},
      },
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
    Object? icon = _unchanged,
    String? creatorName,
    int? reminderMinutes,
    List<TaskChecklistModel>? checklists,
    Map<String, dynamic>? detail,
  }) => PlannerItemModel(
    creatorName: creatorName ?? this.creatorName,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    checklists: checklists ?? this.checklists,
    detail: detail ?? this.detail,
    icon: identical(icon, _unchanged) ? this.icon : icon as String?,
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
    task:
        task ??
        (completed != null
            ? this.task?.copyWith(progress: completed ? 100 : 0)
            : this.task),
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
    icon,
    creatorName,
    reminderMinutes,
    checklists,
    detail,
  ];
  static const _unchanged = Object();
}
