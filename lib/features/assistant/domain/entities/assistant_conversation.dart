import 'package:equatable/equatable.dart';
import 'assistant_message_model.dart';

class AssistantConversation extends Equatable {
  const AssistantConversation({
    required this.id,
    required this.updatedAt,
    this.messages = const [],
    this.draft = '',
    this.projectId,
    this.projectName,
    this.stopped = false,
  });
  final String id, draft;
  final DateTime updatedAt;
  final List<AssistantMessageModel> messages;
  final String? projectId, projectName;
  final bool stopped;
  String get title {
    final text =
        messages
            .where((m) => m.role == 'user' && m.content.trim().isNotEmpty)
            .firstOrNull
            ?.content ??
        draft;
    final title = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return title.isEmpty ? 'Новый диалог' : title;
  }

  AssistantConversation copyWith({
    DateTime? updatedAt,
    List<AssistantMessageModel>? messages,
    String? draft,
    bool? stopped,
  }) => AssistantConversation(
    id: id,
    updatedAt: updatedAt ?? this.updatedAt,
    messages: messages ?? this.messages,
    draft: draft ?? this.draft,
    projectId: projectId,
    projectName: projectName,
    stopped: stopped ?? this.stopped,
  );

  @override
  List<Object?> get props => [
    id,
    updatedAt,
    messages,
    draft,
    projectId,
    projectName,
    stopped,
  ];
}
