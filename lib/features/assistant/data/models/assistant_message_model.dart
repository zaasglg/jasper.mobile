import 'package:equatable/equatable.dart';

class AssistantMessageModel extends Equatable {
  const AssistantMessageModel({
    required this.role,
    required this.content,
    this.images = const [],
    this.tools = const [],
    this.draft,
    this.actionStates = const {},
  });
  factory AssistantMessageModel.fromJson(Map<String, dynamic> json) =>
      AssistantMessageModel(
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
  AssistantMessageModel copyWith({
    String? role,
    String? content,
    List<String>? images,
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? draft,
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
