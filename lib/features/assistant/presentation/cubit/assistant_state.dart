import '../../domain/entities/assistant_conversation.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/assistant_message_model.dart';

enum AssistantStatus { loading, ready, sending, failure }

class AssistantState extends Equatable {
  const AssistantState({
    this.workspaceId = '',
    this.workspaceName = '',
    this.status = AssistantStatus.loading,
    this.messages = const [],
    this.error,
    this.responseRevision = 0,
    this.conversations = const [],
    this.conversationId = '',
    this.draft = '',
    this.historyError,
    this.restoredMessageCount = 0,
    this.stopped = false,
    this.actionBusy = false,
  });
  final String workspaceId, workspaceName;
  final AssistantStatus status;
  final List<AssistantMessageModel> messages;
  final String? error;
  final int responseRevision;
  final List<AssistantConversation> conversations;
  final String conversationId, draft;
  final String? historyError;
  final int restoredMessageCount;
  final bool stopped, actionBusy;
  AssistantState copyWith({
    AssistantStatus? status,
    List<AssistantMessageModel>? messages,
    String? error,
    bool clearError = false,
    int? responseRevision,
    List<AssistantConversation>? conversations,
    String? conversationId,
    String? draft,
    String? historyError,
    bool clearHistoryError = false,
    int? restoredMessageCount,
    bool? stopped,
    bool? actionBusy,
  }) => AssistantState(
    workspaceId: workspaceId,
    workspaceName: workspaceName,
    status: status ?? this.status,
    messages: messages ?? this.messages,
    error: clearError ? null : error ?? this.error,
    responseRevision: responseRevision ?? this.responseRevision,
    conversations: conversations ?? this.conversations,
    conversationId: conversationId ?? this.conversationId,
    draft: draft ?? this.draft,
    historyError: clearHistoryError ? null : historyError ?? this.historyError,
    restoredMessageCount: restoredMessageCount ?? this.restoredMessageCount,
    stopped: stopped ?? this.stopped,
    actionBusy: actionBusy ?? this.actionBusy,
  );
  @override
  List<Object?> get props => [
    workspaceId,
    workspaceName,
    status,
    messages,
    error,
    responseRevision,
    conversations,
    conversationId,
    draft,
    historyError,
    restoredMessageCount,
    stopped,
    actionBusy,
  ];
}
