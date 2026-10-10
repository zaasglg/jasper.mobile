import 'package:equatable/equatable.dart';
import '../../data/models/assistant_message_model.dart';

enum AssistantStatus { loading, ready, sending, failure }

class AssistantState extends Equatable {
  const AssistantState({
    this.workspaceId = '',
    this.workspaceName = '',
    this.status = AssistantStatus.loading,
    this.messages = const [],
    this.error,
    this.responseRevision = 0,
  });
  final String workspaceId, workspaceName;
  final AssistantStatus status;
  final List<AssistantMessageModel> messages;
  final String? error;
  final int responseRevision;
  AssistantState copyWith({
    AssistantStatus? status,
    List<AssistantMessageModel>? messages,
    String? error,
    bool clearError = false,
    int? responseRevision,
  }) => AssistantState(
    workspaceId: workspaceId,
    workspaceName: workspaceName,
    status: status ?? this.status,
    messages: messages ?? this.messages,
    error: clearError ? null : error ?? this.error,
    responseRevision: responseRevision ?? this.responseRevision,
  );
  @override
  List<Object?> get props => [
    workspaceId,
    workspaceName,
    status,
    messages,
    error,
    responseRevision,
  ];
}
