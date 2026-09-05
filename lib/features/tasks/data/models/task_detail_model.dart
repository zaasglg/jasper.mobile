import 'package:equatable/equatable.dart';

import '../../../projects/data/models/project_task_model.dart';

class TaskDetailsPayload extends Equatable {
  const TaskDetailsPayload({
    required this.task,
    required this.detail,
    this.resources = const <TaskResourceModel>[],
  });

  factory TaskDetailsPayload.fromJson(Map<String, dynamic> json) {
    final rawDetail = json['detail'];
    return TaskDetailsPayload(
      task: ProjectTaskModel.fromJson(json),
      detail: rawDetail is Map
          ? TaskDetailModel.fromJson(Map<String, dynamic>.from(rawDetail))
          : const TaskDetailModel(),
      resources: _modelList(json['resources'], TaskResourceModel.fromJson),
    );
  }

  final ProjectTaskModel task;
  final TaskDetailModel detail;
  final List<TaskResourceModel> resources;

  TaskDetailsPayload copyWith({
    ProjectTaskModel? task,
    TaskDetailModel? detail,
    List<TaskResourceModel>? resources,
  }) {
    return TaskDetailsPayload(
      task: task ?? this.task,
      detail: detail ?? this.detail,
      resources: resources ?? this.resources,
    );
  }

  @override
  List<Object?> get props => <Object?>[task, detail, resources];
}

class TaskDetailModel extends Equatable {
  const TaskDetailModel({
    this.description = '',
    this.checklists = const <TaskChecklistModel>[],
    this.comments = const <TaskCommentModel>[],
    this.files = const <TaskFileModel>[],
    this.labels = const <TaskLabelModel>[],
    this.estimateMinutes,
    this.raw = const <String, Object?>{},
  });

  factory TaskDetailModel.fromJson(Map<String, dynamic> json) {
    final rawChecklists = json['checklists'];
    final legacyChecklist = json['checklist'];
    final checklists = rawChecklists is List
        ? _modelList(rawChecklists, TaskChecklistModel.fromJson)
        : legacyChecklist is List
        ? <TaskChecklistModel>[
            TaskChecklistModel(
              id: 'legacy-checklist',
              name: 'Чек-лист',
              items: _modelList(
                legacyChecklist,
                TaskChecklistItemModel.fromJson,
              ),
            ),
          ]
        : const <TaskChecklistModel>[];

    return TaskDetailModel(
      description: json['description']?.toString() ?? '',
      checklists: checklists,
      comments: _modelList(
        json['comments'],
        TaskCommentModel.fromJson,
      ).where((comment) => !comment.isDeleted).toList(growable: false),
      files: _modelList(json['files'], TaskFileModel.fromJson),
      labels: _modelList(json['labels'], TaskLabelModel.fromJson),
      estimateMinutes: json['estimateMinutes'] is num
          ? (json['estimateMinutes'] as num).round()
          : int.tryParse(json['estimateMinutes']?.toString() ?? ''),
      raw: Map<String, Object?>.from(json),
    );
  }

  final String description;
  final List<TaskChecklistModel> checklists;
  final List<TaskCommentModel> comments;
  final List<TaskFileModel> files;
  final List<TaskLabelModel> labels;
  final int? estimateMinutes;
  final Map<String, Object?> raw;

  int get checklistTotal =>
      checklists.fold<int>(0, (total, checklist) => total + checklist.total);

  int get checklistCompleted => checklists.fold<int>(
    0,
    (total, checklist) => total + checklist.completed,
  );

  double get checklistProgress =>
      checklistTotal == 0 ? 0 : checklistCompleted / checklistTotal;

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...raw,
    'description': description,
    'checklists': checklists
        .map((item) => item.toJson())
        .toList(growable: false),
    'comments': comments.map((item) => item.toJson()).toList(growable: false),
    'files': files.map((item) => item.toJson()).toList(growable: false),
    'labels': labels.map((item) => item.toJson()).toList(growable: false),
    if (estimateMinutes != null) 'estimateMinutes': estimateMinutes,
  };

  TaskDetailModel copyWith({
    String? description,
    List<TaskChecklistModel>? checklists,
    List<TaskCommentModel>? comments,
    List<TaskFileModel>? files,
    List<TaskLabelModel>? labels,
    int? estimateMinutes,
    Map<String, Object?>? raw,
  }) {
    return TaskDetailModel(
      description: description ?? this.description,
      checklists: checklists ?? this.checklists,
      comments: comments ?? this.comments,
      files: files ?? this.files,
      labels: labels ?? this.labels,
      estimateMinutes: estimateMinutes ?? this.estimateMinutes,
      raw: raw ?? this.raw,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    description,
    checklists,
    comments,
    files,
    labels,
    estimateMinutes,
    raw,
  ];
}

class TaskChecklistModel extends Equatable {
  const TaskChecklistModel({
    required this.id,
    required this.name,
    this.items = const <TaskChecklistItemModel>[],
    this.sections = const <TaskChecklistSectionModel>[],
    this.raw = const <String, Object?>{},
  });

  factory TaskChecklistModel.fromJson(Map<String, dynamic> json) {
    return TaskChecklistModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Чек-лист',
      items: _modelList(json['items'], TaskChecklistItemModel.fromJson),
      sections: _modelList(
        json['sections'],
        TaskChecklistSectionModel.fromJson,
      ),
      raw: Map<String, Object?>.from(json),
    );
  }

  final String id;
  final String name;
  final List<TaskChecklistItemModel> items;
  final List<TaskChecklistSectionModel> sections;
  final Map<String, Object?> raw;

  Iterable<TaskChecklistItemModel> get allItems sync* {
    yield* items;
    for (final section in sections) {
      yield* section.items;
    }
  }

  int get total => allItems.length;
  int get completed => allItems.where((item) => item.done).length;
  double get progress => total == 0 ? 0 : completed / total;

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...raw,
    'id': id,
    'name': name,
    'items': items.map((item) => item.toJson()).toList(growable: false),
    if (sections.isNotEmpty)
      'sections': sections.map((item) => item.toJson()).toList(growable: false),
  };

  TaskChecklistModel copyWith({
    String? id,
    String? name,
    List<TaskChecklistItemModel>? items,
    List<TaskChecklistSectionModel>? sections,
    Map<String, Object?>? raw,
  }) {
    return TaskChecklistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      sections: sections ?? this.sections,
      raw: raw ?? this.raw,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, name, items, sections, raw];
}

class TaskChecklistSectionModel extends Equatable {
  const TaskChecklistSectionModel({
    required this.id,
    required this.name,
    this.items = const <TaskChecklistItemModel>[],
    this.raw = const <String, Object?>{},
  });

  factory TaskChecklistSectionModel.fromJson(Map<String, dynamic> json) {
    return TaskChecklistSectionModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Раздел',
      items: _modelList(json['items'], TaskChecklistItemModel.fromJson),
      raw: Map<String, Object?>.from(json),
    );
  }

  final String id;
  final String name;
  final List<TaskChecklistItemModel> items;
  final Map<String, Object?> raw;

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...raw,
    'id': id,
    'name': name,
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };

  TaskChecklistSectionModel copyWith({
    String? id,
    String? name,
    List<TaskChecklistItemModel>? items,
    Map<String, Object?>? raw,
  }) {
    return TaskChecklistSectionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      raw: raw ?? this.raw,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, name, items, raw];
}

class TaskChecklistItemModel extends Equatable {
  const TaskChecklistItemModel({
    required this.id,
    required this.text,
    this.done = false,
    this.dueDate,
    this.assigneeIds = const <String>[],
    this.raw = const <String, Object?>{},
  });

  factory TaskChecklistItemModel.fromJson(Map<String, dynamic> json) {
    return TaskChecklistItemModel(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      done: json['done'] == true,
      dueDate: _parseDate(json['dueDate']),
      assigneeIds: _stringList(json['assigneeIds']),
      raw: Map<String, Object?>.from(json),
    );
  }

  final String id;
  final String text;
  final bool done;
  final DateTime? dueDate;
  final List<String> assigneeIds;
  final Map<String, Object?> raw;

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...raw,
    'id': id,
    'text': text,
    'done': done,
    if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
    if (assigneeIds.isNotEmpty) 'assigneeIds': assigneeIds,
  };

  TaskChecklistItemModel copyWith({
    String? id,
    String? text,
    bool? done,
    DateTime? dueDate,
    List<String>? assigneeIds,
    Map<String, Object?>? raw,
  }) {
    return TaskChecklistItemModel(
      id: id ?? this.id,
      text: text ?? this.text,
      done: done ?? this.done,
      dueDate: dueDate ?? this.dueDate,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      raw: raw ?? this.raw,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    text,
    done,
    dueDate,
    assigneeIds,
    raw,
  ];
}

class TaskCommentModel extends Equatable {
  const TaskCommentModel({
    required this.id,
    required this.author,
    required this.text,
    this.authorId,
    this.time = '',
    this.isPinned = false,
    this.deletedAt,
    this.raw = const <String, Object?>{},
  });

  factory TaskCommentModel.fromJson(Map<String, dynamic> json) {
    return TaskCommentModel(
      id: json['id']?.toString() ?? '',
      author: json['author']?.toString() ?? 'Пользователь',
      authorId: _optionalString(json['authorId']),
      time: json['time']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      isPinned:
          json['isPinned'] == true ||
          json['is_pinned'] == true ||
          json['pinnedAt'] != null ||
          json['pinned_at'] != null,
      deletedAt: _parseDate(json['deletedAt'] ?? json['deleted_at']),
      raw: Map<String, Object?>.from(json),
    );
  }

  final String id;
  final String author;
  final String? authorId;
  final String time;
  final String text;
  final bool isPinned;
  final DateTime? deletedAt;
  final Map<String, Object?> raw;

  bool get isDeleted => deletedAt != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...raw,
    'id': id,
    'author': author,
    if (authorId != null) 'authorId': authorId,
    'time': time,
    'text': text,
    if (isPinned) 'isPinned': true,
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
  };

  TaskCommentModel copyWith({
    String? id,
    String? author,
    String? authorId,
    String? time,
    String? text,
    bool? isPinned,
    DateTime? deletedAt,
    Map<String, Object?>? raw,
  }) {
    return TaskCommentModel(
      id: id ?? this.id,
      author: author ?? this.author,
      authorId: authorId ?? this.authorId,
      time: time ?? this.time,
      text: text ?? this.text,
      isPinned: isPinned ?? this.isPinned,
      deletedAt: deletedAt ?? this.deletedAt,
      raw: raw ?? this.raw,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    author,
    authorId,
    time,
    text,
    isPinned,
    deletedAt,
    raw,
  ];
}

class TaskFileModel extends Equatable {
  const TaskFileModel({
    required this.id,
    required this.name,
    this.size = 0,
    this.type = '',
    this.dataUrl,
    this.uploadedByName,
    this.uploadedAt,
    this.raw = const <String, Object?>{},
  });

  factory TaskFileModel.fromJson(Map<String, dynamic> json) {
    return TaskFileModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      size: _parseInt(json['size']),
      type: json['type']?.toString() ?? '',
      dataUrl: _optionalString(json['dataUrl']),
      uploadedByName: _optionalString(json['uploadedByName']),
      uploadedAt: _parseDate(json['uploadedAt']),
      raw: Map<String, Object?>.from(json),
    );
  }

  final String id;
  final String name;
  final int size;
  final String type;
  final String? dataUrl;
  final String? uploadedByName;
  final DateTime? uploadedAt;
  final Map<String, Object?> raw;

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...raw,
    'id': id,
    'name': name,
    'size': size,
    'type': type,
    if (dataUrl != null) 'dataUrl': dataUrl,
    if (uploadedByName != null) 'uploadedByName': uploadedByName,
    if (uploadedAt != null) 'uploadedAt': uploadedAt!.toIso8601String(),
  };

  TaskFileModel copyWith({
    String? id,
    String? name,
    int? size,
    String? type,
    String? dataUrl,
    String? uploadedByName,
    DateTime? uploadedAt,
    Map<String, Object?>? raw,
  }) {
    return TaskFileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      type: type ?? this.type,
      dataUrl: dataUrl ?? this.dataUrl,
      uploadedByName: uploadedByName ?? this.uploadedByName,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      raw: raw ?? this.raw,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    size,
    type,
    dataUrl,
    uploadedByName,
    uploadedAt,
    raw,
  ];
}

class TaskLabelModel extends Equatable {
  const TaskLabelModel({
    required this.id,
    required this.text,
    this.color = '#6366F1',
    this.raw = const <String, Object?>{},
  });

  factory TaskLabelModel.fromJson(Map<String, dynamic> json) {
    return TaskLabelModel(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      color: json['color']?.toString() ?? '#6366F1',
      raw: Map<String, Object?>.from(json),
    );
  }

  final String id;
  final String text;
  final String color;
  final Map<String, Object?> raw;

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...raw,
    'id': id,
    'text': text,
    'color': color,
  };

  TaskLabelModel copyWith({
    String? id,
    String? text,
    String? color,
    Map<String, Object?>? raw,
  }) {
    return TaskLabelModel(
      id: id ?? this.id,
      text: text ?? this.text,
      color: color ?? this.color,
      raw: raw ?? this.raw,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, text, color, raw];
}

class TaskResourceModel extends Equatable {
  const TaskResourceModel({
    required this.id,
    required this.name,
    this.planValue = 0,
    this.factValue = 0,
    this.order = 0,
  });

  factory TaskResourceModel.fromJson(Map<String, dynamic> json) {
    return TaskResourceModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      planValue: _parseDouble(json['planValue']),
      factValue: _parseDouble(json['factValue']),
      order: _parseInt(json['order']),
    );
  }

  final String id;
  final String name;
  final double planValue;
  final double factValue;
  final int order;

  double get ratio => planValue <= 0 ? 0 : factValue / planValue;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'planValue': planValue,
    'factValue': factValue,
    'order': order,
  };

  TaskResourceModel copyWith({
    String? id,
    String? name,
    double? planValue,
    double? factValue,
    int? order,
  }) {
    return TaskResourceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      planValue: planValue ?? this.planValue,
      factValue: factValue ?? this.factValue,
      order: order ?? this.order,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, name, planValue, factValue, order];
}

class TaskHistoryEntryModel extends Equatable {
  const TaskHistoryEntryModel({
    required this.id,
    required this.type,
    required this.createdAt,
    this.actorName,
    this.fromValue,
    this.toValue,
    this.subjectName,
  });

  factory TaskHistoryEntryModel.fromJson(Map<String, dynamic> json) {
    final rawMeta = json['meta'];
    final meta = rawMeta is Map
        ? Map<String, dynamic>.from(rawMeta)
        : const <String, dynamic>{};
    return TaskHistoryEntryModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'task_updated',
      actorName: _optionalString(json['actorName']),
      createdAt:
          _parseDate(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      fromValue: _optionalString(meta['from'] ?? meta['old_value']),
      toValue: _optionalString(meta['to'] ?? meta['new_value']),
      subjectName: _optionalString(meta['name'] ?? meta['label']),
    );
  }

  final String id;
  final String type;
  final String? actorName;
  final DateTime createdAt;
  final String? fromValue;
  final String? toValue;
  final String? subjectName;

  TaskHistoryEntryModel copyWith({
    String? id,
    String? type,
    String? actorName,
    DateTime? createdAt,
    String? fromValue,
    String? toValue,
    String? subjectName,
  }) {
    return TaskHistoryEntryModel(
      id: id ?? this.id,
      type: type ?? this.type,
      actorName: actorName ?? this.actorName,
      createdAt: createdAt ?? this.createdAt,
      fromValue: fromValue ?? this.fromValue,
      toValue: toValue ?? this.toValue,
      subjectName: subjectName ?? this.subjectName,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    type,
    actorName,
    createdAt,
    fromValue,
    toValue,
    subjectName,
  ];
}

List<T> _modelList<T>(
  dynamic value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value is! List) return <T>[];
  return value
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value.map((item) => item.toString()).toList(growable: false);
}

String? _optionalString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int _parseInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
