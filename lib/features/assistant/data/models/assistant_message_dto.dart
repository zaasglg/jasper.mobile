import '../../domain/entities/assistant_attachment.dart';
import '../../domain/entities/assistant_message_model.dart';
import 'assistant_tool_dto.dart';
import 'assistant_draft_dto.dart';
import 'package:equatable/equatable.dart';

class AssistantMessageDto extends Equatable {
  const AssistantMessageDto({
    required this.role,
    required this.content,
    this.images = const [],
    this.attachments = const [],
    this.attachmentMessage,
    this.tools = const [],
    this.draft,
    this.actionStates = const {},
    this.cancelled = false,
  });
  factory AssistantMessageDto.fromJson(Map<String, dynamic> json) =>
      AssistantMessageDto(
        cancelled: json['cancelled'] == true,
        role: json['role']?.toString() ?? 'assistant',
        content: json['content']?.toString() ?? '',
        images: (json['images'] as List? ?? []).whereType<String>().toList(),
        attachments: AssistantAttachment.parseList(json['attachments']),
        attachmentMessage: json['attachmentMessage'] is String
            ? json['attachmentMessage'] as String
            : null,
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
        cancelled: entity.cancelled,
        content: entity.content,
        images: entity.images,
        attachments: entity.attachments,
        attachmentMessage: entity.attachmentMessage,
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
    cancelled: cancelled,
    content: content,
    images: images,
    attachments: attachments,
    attachmentMessage: attachmentMessage,
    tools: tools.map((t) => AssistantToolDto.fromJson(t).toEntity()).toList(),
    draft: draft == null ? null : AssistantDraftDto.fromJson(draft!).toEntity(),
    actionStates: actionStates,
  );
  final bool cancelled;
  final String role, content;
  final List<String> images;
  final List<AssistantAttachment> attachments;
  final String? attachmentMessage;
  final List<Map<String, dynamic>> tools;
  final Map<String, dynamic>? draft;
  final Map<String, String> actionStates;
  Map<String, dynamic> toJson() => {
    'role': role,
    if (cancelled) 'cancelled': true,
    'content': content,
    if (images.isNotEmpty) 'images': images,
    if (attachments.isNotEmpty)
      'attachments': attachments.map((e) => e.toJson()).toList(),
    'attachmentMessage': ?attachmentMessage,
    if (tools.isNotEmpty) 'toolCalls': tools,
    if (draft != null) 'draft': draft,
    if (actionStates.isNotEmpty) 'actionStates': actionStates,
  };
  AssistantMessageDto copyWith({
    String? role,
    String? content,
    List<String>? images,
    List<AssistantAttachment>? attachments,
    String? attachmentMessage,
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? draft,
    Map<String, String>? actionStates,
    bool? cancelled,
  }) => AssistantMessageDto(
    role: role ?? this.role,
    content: content ?? this.content,
    images: images ?? this.images,
    attachments: attachments ?? this.attachments,
    attachmentMessage: attachmentMessage ?? this.attachmentMessage,
    tools: tools ?? this.tools,
    draft: draft ?? this.draft,
    actionStates: actionStates ?? this.actionStates,
    cancelled: cancelled ?? this.cancelled,
  );
  @override
  List<Object?> get props => [
    role,
    content,
    images,
    attachments,
    attachmentMessage,
    tools,
    draft,
    actionStates,
    cancelled,
  ];
}
