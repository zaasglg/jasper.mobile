import 'package:equatable/equatable.dart';

class ProjectModel extends Equatable {
  const ProjectModel({
    required this.id,
    required this.code,
    required this.name,
    required this.workspaceId,
    required this.start,
    required this.end,
    this.description,
    this.progress = 0,
    this.parentId,
    this.isPinned = false,
    this.children = const <ProjectModel>[],
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: _optionalString(json['description']),
      workspaceId:
          json['workspaceId']?.toString() ??
          json['workspace_id']?.toString() ??
          '',
      start: _parseDate(json['start'] ?? json['startDate']),
      end: _parseDate(json['end'] ?? json['endDate']),
      progress: _parseProgress(json['progress']),
      parentId: _optionalString(json['parentId'] ?? json['parent_id']),
      isPinned: _parseBool(json['isPinned'] ?? json['is_pinned']),
      children: _parseChildren(json['children']),
    );
  }

  final String id;
  final String code;
  final String name;
  final String? description;
  final String workspaceId;
  final DateTime? start;
  final DateTime? end;
  final double progress;
  final String? parentId;
  final bool isPinned;
  final List<ProjectModel> children;

  static List<ProjectModel> _parseChildren(dynamic value) {
    if (value is! List) return const <ProjectModel>[];
    return value
        .whereType<Map>()
        .map((item) => ProjectModel.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static String? _optionalString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static double _parseProgress(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return parsed.clamp(0, 100).toDouble();
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString().toLowerCase() == 'true';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'code': code,
    'name': name,
    if (description != null) 'description': description,
    'workspaceId': workspaceId,
    if (start != null) 'start': start!.toUtc().toIso8601String(),
    if (end != null) 'end': end!.toUtc().toIso8601String(),
    'progress': progress,
    if (parentId != null) 'parentId': parentId,
    'isPinned': isPinned,
    'children': children.map((child) => child.toJson()).toList(growable: false),
  };

  ProjectModel copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    String? workspaceId,
    DateTime? start,
    DateTime? end,
    double? progress,
    String? parentId,
    bool? isPinned,
    List<ProjectModel>? children,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      workspaceId: workspaceId ?? this.workspaceId,
      start: start ?? this.start,
      end: end ?? this.end,
      progress: progress ?? this.progress,
      parentId: parentId ?? this.parentId,
      isPinned: isPinned ?? this.isPinned,
      children: children ?? this.children,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    code,
    name,
    description,
    workspaceId,
    start,
    end,
    progress,
    parentId,
    isPinned,
    children,
  ];
}
