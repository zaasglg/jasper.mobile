import 'assistant_attachment.dart';
import 'package:equatable/equatable.dart';
import 'assistant_tool.dart';
import 'assistant_draft.dart';

class AssistantMessageModel extends Equatable {
  const AssistantMessageModel({
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
  final bool cancelled;
  final String role;
  final String content;
  final List<String> images;
  final List<AssistantAttachment> attachments;
  final String? attachmentMessage;
  final List<AssistantTool> tools;
  final AssistantDraft? draft;
  final Map<String, String> actionStates;
  AssistantMessageModel copyWith({
    String? role,
    String? content,
    List<String>? images,
    List<AssistantAttachment>? attachments,
    String? attachmentMessage,
    List<AssistantTool>? tools,
    AssistantDraft? draft,
    Map<String, String>? actionStates,
    bool? cancelled,
  }) => AssistantMessageModel(
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
