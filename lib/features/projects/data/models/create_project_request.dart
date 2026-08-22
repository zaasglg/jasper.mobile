import 'package:equatable/equatable.dart';

class CreateProjectRequest extends Equatable {
  const CreateProjectRequest({
    required this.code,
    required this.name,
    required this.workspaceId,
    required this.start,
    required this.end,
    this.description,
    this.progress = 0,
    this.parentId,
    this.isPinned = false,
  });

  factory CreateProjectRequest.fromJson(Map<String, dynamic> json) {
    return CreateProjectRequest(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: _optional(json['description']),
      workspaceId: json['workspaceId']?.toString() ?? '',
      start: DateTime.parse(json['start'].toString()),
      end: DateTime.parse(json['end'].toString()),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      parentId: _optional(json['parentId']),
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }

  final String code;
  final String name;
  final String? description;
  final String workspaceId;
  final DateTime start;
  final DateTime end;
  final double progress;
  final String? parentId;
  final bool isPinned;

  static String? _optional(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'code': code.trim(),
      'name': name.trim(),
      'workspaceId': workspaceId,
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
      'progress': progress,
      'isPinned': isPinned,
    };
    final normalizedDescription = _optional(description);
    final normalizedParentId = _optional(parentId);
    if (normalizedDescription != null) {
      json['description'] = normalizedDescription;
    }
    if (normalizedParentId != null) json['parentId'] = normalizedParentId;
    return json;
  }

  CreateProjectRequest copyWith({
    String? code,
    String? name,
    String? description,
    String? workspaceId,
    DateTime? start,
    DateTime? end,
    double? progress,
    String? parentId,
    bool? isPinned,
  }) {
    return CreateProjectRequest(
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      workspaceId: workspaceId ?? this.workspaceId,
      start: start ?? this.start,
      end: end ?? this.end,
      progress: progress ?? this.progress,
      parentId: parentId ?? this.parentId,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    code,
    name,
    description,
    workspaceId,
    start,
    end,
    progress,
    parentId,
    isPinned,
  ];
}
