import 'package:equatable/equatable.dart';

class TaskMoveTarget extends Equatable {
  const TaskMoveTarget({
    required this.workspaceId,
    required this.projectId,
    required this.status,
    this.position,
  });
  final String workspaceId, projectId, status;

  /// Null appends to the destination column using the server's current count.
  final int? position;
  factory TaskMoveTarget.fromJson(Map<String, dynamic> json) => TaskMoveTarget(
    workspaceId: json['workspaceId'] as String,
    projectId: json['projectId'] as String,
    status: json['status'] as String,
    position: (json['position'] as num?)?.toInt(),
  );
  Map<String, dynamic> toJson() => {
    'workspaceId': workspaceId,
    'projectId': projectId,
    'status': status,
    'position': ?position,
  };
  TaskMoveTarget copyWith({
    String? workspaceId,
    String? projectId,
    String? status,
    Object? position = _unchanged,
  }) => TaskMoveTarget(
    workspaceId: workspaceId ?? this.workspaceId,
    projectId: projectId ?? this.projectId,
    status: status ?? this.status,
    position: identical(position, _unchanged)
        ? this.position
        : position as int?,
  );
  static const _unchanged = Object();
  @override
  List<Object?> get props => [workspaceId, projectId, status, position];
}
