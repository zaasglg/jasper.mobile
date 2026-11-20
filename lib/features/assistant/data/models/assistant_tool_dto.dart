import 'package:equatable/equatable.dart';
import '../../domain/entities/assistant_tool.dart';
import '../../domain/entities/assistant_tool_result.dart';
import 'assistant_draft_dto.dart';

class AssistantToolDto extends Equatable {
  const AssistantToolDto(this.value);
  final Map<String, dynamic> value;
  factory AssistantToolDto.fromJson(Map<String, dynamic> json) =>
      AssistantToolDto(Map.of(json));
  Map<String, dynamic> toJson() => Map.of(value);
  factory AssistantToolDto.fromEntity(
    AssistantTool entity,
  ) => AssistantToolDto({
    'name': entity.name,
    if (entity.result != null)
      'result': {
        if (entity.result!.updated != null) 'updated': entity.result!.updated,
        if (entity.result!.action != null) 'action': entity.result!.action,
        if (entity.result!.results != null) 'results': entity.result!.results,
        if (entity.result!.draft != null)
          'draft': AssistantDraftDto.fromEntity(entity.result!.draft!).toJson(),
        if (entity.result!.hasError || entity.result!.error != null)
          'error': entity.result!.error,
        if (entity.result!.attachment != null)
          'attachment': entity.result!.attachment,
      },
  });
  AssistantTool toEntity() {
    final raw = value['result'];
    Map<String, dynamic>? map(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;
    return AssistantTool(
      name: value['name'] is String ? value['name'] as String : '',
      result: raw is Map
          ? AssistantToolResult(
              updated: map(raw['updated']),
              action: map(raw['action']),
              results: raw['results'] is List
                  ? List.of(raw['results'] as List)
                  : null,
              draft: raw['draft'] is Map
                  ? AssistantDraftDto.fromJson(
                      Map<String, dynamic>.from(raw['draft'] as Map),
                    ).toEntity()
                  : null,
              error: raw['error'],
              hasError: raw.containsKey('error'),
              attachment: map(raw['attachment']),
            )
          : null,
    );
  }

  AssistantToolDto copyWith({Map<String, dynamic>? value}) =>
      AssistantToolDto(value ?? this.value);
  @override
  List<Object?> get props => [value];
}
