import 'dart:convert';
import 'package:equatable/equatable.dart';
import '../../../tasks/data/models/task_label_dto.dart';
import '../../domain/entities/project_task_model.dart';
import 'task_assignee_dto.dart';
import 'task_epic_dto.dart';
import 'project_task_detail_snapshot_dto.dart';

class ProjectTaskDto extends Equatable {
  const ProjectTaskDto({
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
    this.assignees = const <TaskAssigneeDto>[],
    this.epics = const <TaskEpicDto>[],
    this.labels = const <TaskLabelDto>[],
  });

  factory ProjectTaskDto.fromJson(Map<String, dynamic> json) {
    return ProjectTaskDto(
      id: json['id']?.toString() ?? '',
      displayId:
          json['displayId']?.toString() ?? json['display_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      projectId:
          json['projectId']?.toString() ?? json['project_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      progress: _parseProgress(json['progress']),
      priority: json['priority']?.toString() ?? 'MED',
      detail: json['detail'] is Map
          ? jsonEncode(json['detail'])
          : _optionalString(json['detail']),
      deps: (json['deps'] is List)
          ? (json['deps'] as List).map((e) => e.toString()).toList()
          : const [],
      start: _parseDate(json['start']),
      end: _parseDate(json['end']),
      order: _parseInt(json['order']) ?? 0,
      estimate:
          double.tryParse(
            (json['est'] ?? json['estimate'])?.toString() ?? '',
          ) ??
          0,
      timerStartedAt: _parseDate(json['timerStartedAt']),
      timerElapsedMs: _parseInt(json['timerElapsedMs']) ?? 0,
      isTimingEnabled: json['isTimingEnabled'] != false,
      archived: _parseBool(json['archived']),
      commentCount: _commentCount(json),
      fileCount: _fileCount(json),
      resourceCount:
          _parseInt(json['resourcesCount'] ?? json['resourceCount']) ??
          (json['resources'] is List ? (json['resources'] as List).length : 0),
      checklistCompleted: _checklistCompleted(json),
      checklistTotal: _checklistTotal(json),
      assignees: _parseAssignees(json['assignees']),
      epics: _parseEpics(json['epics']),
      labels: _parseLabels(json),
    );
  }

  final String id;
  final String displayId;
  final String title;
  final String projectId;
  final String status;
  final double? progress;
  final String priority;
  final String? detail;
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
  final List<TaskAssigneeDto> assignees;
  final List<TaskEpicDto> epics;
  final List<TaskLabelDto> labels;

  static Map<dynamic, dynamic> _detailObject(dynamic detail) {
    if (detail is String) {
      try {
        detail = jsonDecode(detail);
      } on FormatException {
        return const {};
      }
    }
    return detail is Map ? detail : const {};
  }

  static int _fileCount(Map<String, dynamic> json) {
    final explicit = _parseInt(json['filesCount'] ?? json['fileCount']);
    if (explicit != null) return explicit < 0 ? 0 : explicit;
    final files = json['files'] ?? _detailObject(json['detail'])['files'];
    return files is List ? files.whereType<Map>().length : 0;
  }

  static List<TaskLabelDto> _parseLabels(Map<String, dynamic> json) {
    final detail = _detailObject(json['detail']);
    final values = json['labels'] ?? detail['labels'];
    final personal = json['personalLabels'] ?? detail['personalLabels'];
    final labels = <TaskLabelDto>[
      if (values is List)
        for (final value in values.whereType<Map>())
          TaskLabelDto.fromJson(Map<String, dynamic>.from(value)),
      if (personal is List)
        for (final value in personal.whereType<Map>())
          TaskLabelDto.fromJson(
            Map<String, dynamic>.from(value),
          ).copyWith(isPersonal: true),
    ];
    final seen = <String>{};
    return labels
        .where((label) {
          if (label.text.trim().isEmpty) return false;
          final identity =
              '${label.isPersonal}:${label.id.isEmpty ? '${label.text}:${label.color}' : label.id}';
          return seen.add(identity);
        })
        .toList(growable: false);
  }

  static double? _parseProgress(dynamic value) {
    if (value == null) return null;
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value.toString());
    return parsed?.clamp(0, 100).toDouble();
  }

  static String? _optionalString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString().toLowerCase() == 'true';
  }

  static int _commentCount(Map<String, dynamic> json) {
    final explicit = _parseInt(json['commentsCount'] ?? json['commentCount']);
    if (explicit != null) return explicit < 0 ? 0 : explicit;
    final comments =
        _detailObject(json['detail'])['comments'] ?? json['comments'];
    if (comments is List) {
      return comments
          .whereType<Map>()
          .where(
            (comment) =>
                comment['deletedAt'] == null && comment['deleted_at'] == null,
          )
          .length;
    }
    final count = _parseInt(comments) ?? 0;
    return count < 0 ? 0 : count;
  }

  static Iterable<Map> _checklistItems(Map<String, dynamic> json) sync* {
    final detail = _detailObject(json['detail']);
    final lists = json['checklists'] ?? detail['checklists'];
    if (lists is List) {
      for (final checklist in lists.whereType<Map>()) {
        final items = checklist['items'];
        if (items is List) yield* items.whereType<Map>();
        final sections = checklist['sections'];
        if (sections is List) {
          for (final section in sections.whereType<Map>()) {
            final sectionItems = section['items'];
            if (sectionItems is List) yield* sectionItems.whereType<Map>();
          }
        }
      }
      return;
    }
    final items =
        json['checklist'] ?? json['checklistItems'] ?? detail['checklist'];
    if (items is List) yield* items.whereType<Map>();
  }

  static int _checklistTotal(Map<String, dynamic> json) {
    return _parseInt(json['checklistTotal']) ?? _checklistItems(json).length;
  }

  static int _checklistCompleted(Map<String, dynamic> json) {
    return _parseInt(json['checklistCompleted']) ??
        _checklistItems(json)
            .where(
              (item) => _parseBool(
                item['completed'] ?? item['isCompleted'] ?? item['done'],
              ),
            )
            .length;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    final DateTime? parsed;
    if (value is num) {
      if (value == 0) return null;
      final raw = value.toInt();
      parsed = DateTime.fromMillisecondsSinceEpoch(
        raw.abs() < 100000000000 ? raw * 1000 : raw,
        isUtc: true,
      );
    } else {
      parsed = DateTime.tryParse(value.toString());
    }

    // The backend can return the Unix epoch for an unset deadline.
    if (parsed == null || parsed.year <= 1971) return null;
    return parsed;
  }

  static List<TaskAssigneeDto> _parseAssignees(dynamic value) {
    if (value is! List) return const <TaskAssigneeDto>[];
    return value
        .whereType<Map>()
        .map(
          (item) => TaskAssigneeDto.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  static List<TaskEpicDto> _parseEpics(dynamic value) {
    if (value is! List) return const <TaskEpicDto>[];
    return value
        .whereType<Map>()
        .map((item) => TaskEpicDto.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'deps': deps,
    'id': id,
    'displayId': displayId,
    'title': title,
    'projectId': projectId,
    'status': status,
    if (progress != null) 'progress': progress,
    'priority': priority,
    if (detail != null) 'detail': detail,
    if (start != null) 'start': start!.toUtc().toIso8601String(),
    if (end != null) 'end': end!.toUtc().toIso8601String(),
    'order': order,
    'est': estimate,
    'timerStartedAt': timerStartedAt?.toUtc().toIso8601String(),
    'timerElapsedMs': timerElapsedMs,
    'isTimingEnabled': isTimingEnabled,
    'archived': archived,
    'commentsCount': commentCount,
    'filesCount': fileCount,
    'resourcesCount': resourceCount,
    'checklistCompleted': checklistCompleted,
    'checklistTotal': checklistTotal,
    'assignees': assignees.map((item) => item.toJson()).toList(growable: false),
    'epics': epics.map((item) => item.toJson()).toList(growable: false),
    'labels': labels.map((item) => item.toJson()).toList(growable: false),
  };

  ProjectTaskDto copyWith({
    String? id,
    String? displayId,
    String? title,
    String? projectId,
    String? status,
    double? progress,
    String? priority,
    String? detail,
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
    List<TaskAssigneeDto>? assignees,
    List<TaskEpicDto>? epics,
    List<TaskLabelDto>? labels,
  }) {
    return ProjectTaskDto(
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

  factory ProjectTaskDto.fromEntity(ProjectTaskModel entity) => ProjectTaskDto(
    id: entity.id,
    displayId: entity.displayId,
    title: entity.title,
    projectId: entity.projectId,
    status: entity.status,
    progress: entity.progress,
    priority: entity.priority,
    detail: entity.detail == null
        ? null
        : ProjectTaskDetailSnapshotDto.fromEntity(entity.detail!).toApiValue(),
    deps: entity.deps,
    start: entity.start,
    end: entity.end,
    order: entity.order,
    estimate: entity.estimate,
    timerStartedAt: entity.timerStartedAt,
    timerElapsedMs: entity.timerElapsedMs,
    isTimingEnabled: entity.isTimingEnabled,
    archived: entity.archived,
    commentCount: entity.commentCount,
    fileCount: entity.fileCount,
    resourceCount: entity.resourceCount,
    checklistCompleted: entity.checklistCompleted,
    checklistTotal: entity.checklistTotal,
    assignees: entity.assignees
        .map(TaskAssigneeDto.fromEntity)
        .toList(growable: false),
    epics: entity.epics.map(TaskEpicDto.fromEntity).toList(growable: false),
    labels: entity.labels.map(TaskLabelDto.fromEntity).toList(growable: false),
  );
  ProjectTaskModel toEntity() => ProjectTaskModel(
    id: id,
    displayId: displayId,
    title: title,
    projectId: projectId,
    status: status,
    progress: progress,
    priority: priority,
    detail: detail == null
        ? null
        : ProjectTaskDetailSnapshotDto.parse(detail!).toEntity(),
    deps: deps,
    start: start,
    end: end,
    order: order,
    estimate: estimate,
    timerStartedAt: timerStartedAt,
    timerElapsedMs: timerElapsedMs,
    isTimingEnabled: isTimingEnabled,
    archived: archived,
    commentCount: commentCount,
    fileCount: fileCount,
    resourceCount: resourceCount,
    checklistCompleted: checklistCompleted,
    checklistTotal: checklistTotal,
    assignees: assignees.map((e) => e.toEntity()).toList(growable: false),
    epics: epics.map((e) => e.toEntity()).toList(growable: false),
    labels: labels.map((e) => e.toEntity()).toList(growable: false),
  );
}
