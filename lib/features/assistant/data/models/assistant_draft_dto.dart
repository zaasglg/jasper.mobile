import 'package:equatable/equatable.dart';
import '../../domain/entities/assistant_draft.dart';
import '../../domain/entities/assistant_draft_previous.dart';

class AssistantDraftDto extends Equatable {
  const AssistantDraftDto(this.value);
  final Map<String, dynamic> value;
  factory AssistantDraftDto.fromJson(Map<String, dynamic> json) =>
      AssistantDraftDto(Map.of(json));
  Map<String, dynamic> toJson() => Map.of(value);
  factory AssistantDraftDto.fromEntity(AssistantDraft entity) =>
      AssistantDraftDto({
        'type': entity.type,
        'workspaceId': entity.workspaceId,
        'projectId': entity.projectId,
        'taskId': entity.taskId,
        'title': entity.title,
        'description': entity.description,
        'dueDate': entity.dueDate,
        'suggestedAssigneeName': entity.suggestedAssigneeName,
        'resolvedAssigneeId': entity.resolvedAssigneeId,
        if (entity.hasPatch) 'patch': entity.patch,
        if (entity.previous != null)
          'previous': {
            'title': entity.previous!.title,
            'start': entity.previous!.start,
            'end': entity.previous!.end,
            'priority': entity.previous!.priority,
          },
      });
  AssistantDraft toEntity() {
    final previous = value['previous'];
    String? text(String key) =>
        value[key] is String ? value[key] as String : null;
    return AssistantDraft(
      type: text('type'),
      workspaceId: text('workspaceId'),
      projectId: text('projectId'),
      taskId: text('taskId'),
      title: text('title'),
      description: text('description'),
      dueDate: text('dueDate'),
      suggestedAssigneeName: text('suggestedAssigneeName'),
      resolvedAssigneeId: text('resolvedAssigneeId'),
      patch: value['patch'] is Map
          ? Map<String, dynamic>.from(value['patch'] as Map)
          : const {},
      hasPatch: value['patch'] is Map,
      previous: previous is Map
          ? AssistantDraftPrevious(
              hasValidValues: ['title', 'start', 'end', 'priority'].every(
                (key) => previous[key] == null || previous[key] is String,
              ),
              title: previous['title'] is String
                  ? previous['title'] as String
                  : null,
              start: previous['start'] is String
                  ? previous['start'] as String
                  : null,
              end: previous['end'] is String ? previous['end'] as String : null,
              priority: previous['priority'] is String
                  ? previous['priority'] as String
                  : null,
            )
          : null,
    );
  }

  AssistantDraftDto copyWith({Map<String, dynamic>? value}) =>
      AssistantDraftDto(value ?? this.value);
  @override
  List<Object?> get props => [value];
}
