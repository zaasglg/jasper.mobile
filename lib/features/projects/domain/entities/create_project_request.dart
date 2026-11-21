import 'package:equatable/equatable.dart';

class CreateProjectRequest extends Equatable {
  const CreateProjectRequest({
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

  final String code;
  final String name;
  final String? description;
  final String workspaceId;
  final DateTime? start;
  final DateTime? end;
  final double progress;
  final String? parentId;
  final bool isPinned;

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
