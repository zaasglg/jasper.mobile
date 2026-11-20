import 'package:equatable/equatable.dart';
import 'assistant_tool.dart';
import 'assistant_draft.dart';

class AssistantMessageModel extends Equatable {
  const AssistantMessageModel({
    required this.role,
    required this.content,
    this.images = const [],
    this.tools = const [],
    this.draft,
    this.actionStates = const {},
  });
  final String role;
  final String content;
  final List<String> images;
  final List<AssistantTool> tools;
  final AssistantDraft? draft;
  final Map<String, String> actionStates;
  AssistantMessageModel copyWith({
    String? role,
    String? content,
    List<String>? images,
    List<AssistantTool>? tools,
    AssistantDraft? draft,
    Map<String, String>? actionStates,
  }) => AssistantMessageModel(
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
