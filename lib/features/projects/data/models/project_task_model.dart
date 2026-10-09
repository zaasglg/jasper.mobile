import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../../tasks/data/models/task_label_model.dart';

class ProjectTaskModel extends Equatable {
  const ProjectTaskModel({
    required this.id,
    required this.projectId,
    required this.status,
    this.displayId = '',
    this.title = '',
    this.progress,
    this.priority = 'MED',
    this.detail,
    this.start,
    this.end,
    this.order = 0,
    this.estimate = 0,
    this.archived = false,
    this.commentCount = 0,
    this.fileCount = 0,
    this.checklistCompleted = 0,
    this.checklistTotal = 0,
    this.assignees = const <TaskAssigneeModel>[],
    this.epics = const <TaskEpicModel>[],
    this.labels = const <TaskLabelModel>[],
  });

  factory ProjectTaskModel.fromJson(Map<String, dynamic> json) {
    return ProjectTaskModel(
      id: json['id']?.toString() ?? '',
      displayId:
          json['displayId']?.toString() ?? json['display_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      projectId:
          json['projectId']?.toString() ?? json['project_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      progress: _parseProgress(json['progress']),
      priority: json['priority']?.toString() ?? 'MED',
      detail: _optionalString(json['detail']),
      start: _parseDate(json['start']),
      end: _parseDate(json['end']),
      order: _parseInt(json['order']) ?? 0,
      estimate: _parseInt(json['est'] ?? json['estimate']) ?? 0,
      archived: _parseBool(json['archived']),
      commentCount: _commentCount(json),
      fileCount: _fileCount(json),
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
  final DateTime? start;
  final DateTime? end;
  final int order;
  final int estimate;
  final bool archived;
  final int commentCount;
  final int fileCount;
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

  static List<TaskLabelModel> _parseLabels(Map<String, dynamic> json) {
    final detail = _detailObject(json['detail']);
    final values = json['labels'] ?? detail['labels'];
    final personal = json['personalLabels'] ?? detail['personalLabels'];
    final labels = <TaskLabelModel>[
      if (values is List)
        for (final value in values.whereType<Map>())
          TaskLabelModel.fromJson(Map<String, dynamic>.from(value)),
      if (personal is List)
        for (final value in personal.whereType<Map>())
          TaskLabelModel.fromJson(
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

  static List<TaskAssigneeModel> _parseAssignees(dynamic value) {
    if (value is! List) return const <TaskAssigneeModel>[];
    return value
        .whereType<Map>()
        .map(
          (item) => TaskAssigneeModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  static List<TaskEpicModel> _parseEpics(dynamic value) {
    if (value is! List) return const <TaskEpicModel>[];
    return value
        .whereType<Map>()
        .map((item) => TaskEpicModel.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
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
    'archived': archived,
    'commentsCount': commentCount,
    'filesCount': fileCount,
    'checklistCompleted': checklistCompleted,
    'checklistTotal': checklistTotal,
    'assignees': assignees.map((item) => item.toJson()).toList(growable: false),
    'epics': epics.map((item) => item.toJson()).toList(growable: false),
    'labels': labels.map((item) => item.toJson()).toList(growable: false),
  };

  ProjectTaskModel copyWith({
    String? id,
    String? displayId,
    String? title,
    String? projectId,
    String? status,
    double? progress,
    String? priority,
    String? detail,
    DateTime? start,
    DateTime? end,
    int? order,
    int? estimate,
    bool? archived,
    int? commentCount,
    int? fileCount,
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
      start: start ?? this.start,
      end: end ?? this.end,
      order: order ?? this.order,
      estimate: estimate ?? this.estimate,
      archived: archived ?? this.archived,
      commentCount: commentCount ?? this.commentCount,
      fileCount: fileCount ?? this.fileCount,
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
    start,
    end,
    order,
    estimate,
    archived,
    commentCount,
    fileCount,
    checklistCompleted,
    checklistTotal,
    assignees,
    epics,
    labels,
  ];
}

class TaskAssigneeModel extends Equatable {
  const TaskAssigneeModel({
    required this.userId,
    this.name = '',
    this.avatarUrl,
  });

  factory TaskAssigneeModel.fromJson(Map<String, dynamic> json) {
    final nestedUser = json['user'];
    final nestedId = nestedUser is Map ? nestedUser['id'] : null;
    final user = nestedUser is Map
        ? Map<String, dynamic>.from(nestedUser)
        : const <String, dynamic>{};
    final firstName = user['firstName']?.toString().trim() ?? '';
    final lastName = user['lastName']?.toString().trim() ?? '';
    final fullName = '$firstName $lastName'.trim();
    return TaskAssigneeModel(
      userId:
          json['userId']?.toString() ??
          json['user_id']?.toString() ??
          nestedId?.toString() ??
          '',
      name:
          user['name']?.toString().trim() ??
          json['name']?.toString().trim() ??
          fullName,
      avatarUrl: _optionalString(
        user['avatarUrl'] ??
            user['avatar_url'] ??
            user['avatar'] ??
            json['avatarUrl'] ??
            json['avatar_url'] ??
            json['avatar'],
      ),
    );
  }

  final String userId;
  final String name;
  final String? avatarUrl;

  static String? _optionalString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'userId': userId,
    if (name.isNotEmpty) 'name': name,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
  };

  TaskAssigneeModel copyWith({
    String? userId,
    String? name,
    String? avatarUrl,
  }) {
    return TaskAssigneeModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  List<Object?> get props => <Object?>[userId, name, avatarUrl];
}

class TaskEpicModel extends Equatable {
  const TaskEpicModel({
    required this.id,
    required this.name,
    this.color = '#6d5fe0',
  });

  factory TaskEpicModel.fromJson(Map<String, dynamic> json) {
    final nestedEpic = json['epic'];
    final epic = nestedEpic is Map
        ? Map<String, dynamic>.from(nestedEpic)
        : const <String, dynamic>{};
    return TaskEpicModel(
      id:
          json['epicId']?.toString() ??
          json['epic_id']?.toString() ??
          epic['id']?.toString() ??
          json['id']?.toString() ??
          '',
      name: epic['name']?.toString() ?? json['name']?.toString() ?? '',
      color:
          epic['color']?.toString() ?? json['color']?.toString() ?? '#6d5fe0',
    );
  }

  final String id;
  final String name;
  final String color;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'epicId': id,
    'epic': <String, dynamic>{'id': id, 'name': name, 'color': color},
  };

  TaskEpicModel copyWith({String? id, String? name, String? color}) {
    return TaskEpicModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, name, color];
}
