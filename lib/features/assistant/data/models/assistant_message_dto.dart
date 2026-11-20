import '../../domain/entities/assistant_message_model.dart';
import 'assistant_tool_dto.dart';
import 'assistant_draft_dto.dart';
import 'package:equatable/equatable.dart';

class AssistantMessageDto extends Equatable {
  const AssistantMessageDto({
    required this.role,
    required this.content,
    this.images = const [],
    this.tools = const [],
    this.draft,
    this.actionStates = const {},
  });
  factory AssistantMessageDto.fromJson(Map<String, dynamic> json) =>
      AssistantMessageDto(
        role: json['role']?.toString() ?? 'assistant',
        content: json['content']?.toString() ?? '',
        images: (json['images'] as List? ?? []).whereType<String>().toList(),
        tools: (json['toolCalls'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        draft: json['draft'] is Map
            ? Map<String, dynamic>.from(json['draft'] as Map)
            : null,
        actionStates: (json['actionStates'] as Map? ?? {}).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      );
  factory AssistantMessageDto.fromEntity(AssistantMessageModel entity) =>
      AssistantMessageDto(
        role: entity.role,
        content: entity.content,
        images: entity.images,
        tools: entity.tools
            .map((t) => AssistantToolDto.fromEntity(t).toJson())
            .toList(),
        draft: entity.draft == null
            ? null
            : AssistantDraftDto.fromEntity(entity.draft!).toJson(),
        actionStates: entity.actionStates,
      );
  AssistantMessageModel toEntity() => AssistantMessageModel(
    role: role,
    content: content,
    images: images,
    tools: tools.map((t) => AssistantToolDto.fromJson(t).toEntity()).toList(),
    draft: draft == null ? null : AssistantDraftDto.fromJson(draft!).toEntity(),
    actionStates: actionStates,
  );
  final String role, content;
  final List<String> images;
  final List<Map<String, dynamic>> tools;
  final Map<String, dynamic>? draft;
  final Map<String, String> actionStates;
  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    if (images.isNotEmpty) 'images': images,
    if (tools.isNotEmpty) 'toolCalls': tools,
    if (draft != null) 'draft': draft,
    if (actionStates.isNotEmpty) 'actionStates': actionStates,
  };
  AssistantMessageDto copyWith({
    String? role,
    String? content,
    List<String>? images,
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? draft,
    Map<String, String>? actionStates,
  }) => AssistantMessageDto(
    role: role ?? this.role,
    content: content ?? this.content,
    images: images ?? this.images,
    tools: tools ?? this.tools,
    draft: draft ?? this.draft,
    actionStates: actionStates ?? this.actionStates,
  );
  @override
  List<Object?> get props => [
    role,
    content,
    images,
    tools,
    draft,
    actionStates,
  ];
}
