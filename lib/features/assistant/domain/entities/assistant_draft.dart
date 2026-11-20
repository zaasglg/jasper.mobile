import 'package:equatable/equatable.dart';
import 'assistant_draft_previous.dart';

class AssistantDraft extends Equatable {
  const AssistantDraft({
    this.type,
    this.workspaceId,
    this.projectId,
    this.taskId,
    this.title,
    this.description,
    this.dueDate,
    this.suggestedAssigneeName,
    this.resolvedAssigneeId,
    this.patch = const {},
    this.previous,
    this.hasPatch = true,
  });
  final String? type;
  final String? workspaceId;
  final String? projectId;
  final String? taskId;
  final String? title;
  final String? description;
  final String? dueDate;
  final String? suggestedAssigneeName;
  final String? resolvedAssigneeId;
  final Map<String, dynamic> patch;
  final AssistantDraftPrevious? previous;
  final bool hasPatch;
  AssistantDraft copyWith({
    String? type,
    String? workspaceId,
    String? projectId,
    String? taskId,
    String? title,
    String? description,
    String? dueDate,
    String? suggestedAssigneeName,
    String? resolvedAssigneeId,
    Map<String, dynamic>? patch,
    AssistantDraftPrevious? previous,
    bool? hasPatch,
  }) => AssistantDraft(
    type: type ?? this.type,
    workspaceId: workspaceId ?? this.workspaceId,
    projectId: projectId ?? this.projectId,
    taskId: taskId ?? this.taskId,
    title: title ?? this.title,
    description: description ?? this.description,
    dueDate: dueDate ?? this.dueDate,
    suggestedAssigneeName: suggestedAssigneeName ?? this.suggestedAssigneeName,
    resolvedAssigneeId: resolvedAssigneeId ?? this.resolvedAssigneeId,
    patch: patch ?? this.patch,
    previous: previous ?? this.previous,
    hasPatch: hasPatch ?? this.hasPatch,
  );
  @override
  List<Object?> get props => [
    type,
    workspaceId,
    projectId,
    taskId,
    title,
    description,
    dueDate,
    suggestedAssigneeName,
    resolvedAssigneeId,
    patch,
    previous,
    hasPatch,
  ];
}
