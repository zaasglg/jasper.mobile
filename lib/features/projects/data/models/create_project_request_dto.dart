import 'package:equatable/equatable.dart';
import '../../domain/entities/create_project_request.dart';

class CreateProjectRequestDto extends Equatable {
  const CreateProjectRequestDto({
    required this.code,
    required this.name,
    required this.workspaceId,
    this.start,
    this.end,
    this.description,
    this.progress = 0,
    this.parentId,
    this.isPinned = false,
  });

  factory CreateProjectRequestDto.fromJson(Map<String, dynamic> json) {
    return CreateProjectRequestDto(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: _optional(json['description']),
      workspaceId: json['workspaceId']?.toString() ?? '',
      start: DateTime.tryParse(json['start']?.toString() ?? ''),
      end: DateTime.tryParse(json['end']?.toString() ?? ''),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      parentId: _optional(json['parentId']),
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }

  final String code;
  final String name;
  final String? description;
  final String workspaceId;
  final DateTime? start;
  final DateTime? end;
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
      if (start != null) 'start': start!.toUtc().toIso8601String(),
      if (end != null) 'end': end!.toUtc().toIso8601String(),
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

  CreateProjectRequestDto copyWith({
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
    return CreateProjectRequestDto(
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

  factory CreateProjectRequestDto.fromEntity(CreateProjectRequest entity) =>
      CreateProjectRequestDto(
        code: entity.code,
        name: entity.name,
        description: entity.description,
        workspaceId: entity.workspaceId,
        start: entity.start,
        end: entity.end,
        progress: entity.progress,
        parentId: entity.parentId,
        isPinned: entity.isPinned,
      );
  CreateProjectRequest toEntity() => CreateProjectRequest(
    code: code,
    name: name,
    description: description,
    workspaceId: workspaceId,
    start: start,
    end: end,
    progress: progress,
    parentId: parentId,
    isPinned: isPinned,
  );
}
