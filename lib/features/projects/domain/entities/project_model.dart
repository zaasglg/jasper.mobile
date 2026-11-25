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
    bool clearParentId = false,
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
      parentId: clearParentId ? null : parentId ?? this.parentId,
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
