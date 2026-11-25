import '../entities/assistant_conversation.dart';

abstract interface class AssistantHistoryRepository {
  /// Captures an immutable account/workspace key for subsequent writes.
  Future<String?> scope(String workspaceId);
  Future<List<AssistantConversation>> load(String scope);
  Future<void> save(String scope, List<AssistantConversation> conversations);
}
