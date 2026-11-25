import '../../../collaboration/domain/entities/space_member.dart';
import '../../data/models/chat_conversation_model.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/models/chat_interaction_models.dart';

abstract interface class ChannelMembersRepository {
  Future<List<SpaceMember>> workspaceChannelCandidates();
}

abstract interface class ChatThreadActionsRepository {
  Future<void> clearConversation(String threadId);
  Future<void> deleteConversation(String threadId);
}

abstract interface class ChatRefreshRepository {
  Future<List<ChatMessageModel>> refreshMessages(
    String threadId,
    List<ChatMessageModel> previous,
  );
}

abstract interface class ChatInteractionRepository {
  Future<ChatMessageModel> togglePin(String messageId);
  Future<ChatMessageModel> react(String messageId, String emoji);
  Future<ChatMessageModel> forwardMessage(
    ChatMessageModel message,
    ChatConversationModel target,
  );
  Future<String> interactionWorkspaceId();
  Future<List<ChatTypingUser>> typing(String threadId, String workspaceId);
  Future<void> updateTyping(String threadId, String workspaceId, bool typing);
}

abstract interface class ChatActionsRepository {
  Future<void> toggleFavorite(String messageId);
  Future<void> editMessage(String messageId, String text);
  Future<void> deleteMessage(String messageId);
  Future<void> markRead(String threadId);
  Future<void> renameChannel(String channelId, String name);
  Future<void> leaveChannel(String channelId);
  Future<void> deleteChannel(String channelId);
  Future<List<SpaceMember>> channelMembers(String channelId);
  Future<void> setChannelMembers(String channelId, List<String> userIds);
}

abstract interface class ChatRepository {
  Future<List<ChatConversationModel>> getConversations();
  Future<ChatConversationModel> createChannel({
    required String name,
    String? parentId,
  });
  Future<List<ChatMessageModel>> getMessages(String threadId);
  Future<ChatMessageModel> sendMessage({
    required ChatConversationModel conversation,
    required String text,
    ChatMessageKind kind = ChatMessageKind.text,
    String? transcript,
    String? mention,
    int? duration,
  });
}

abstract interface class ChatOutboxRepository {
  Future<List<ChatMessageModel>> pendingMessages(String threadId);
  Future<ChatMessageModel> enqueueMessage(String threadId, String text);
  Future<ChatMessageModel> sendPending(ChatMessageModel message);
}

class ChatException implements Exception {
  const ChatException(this.message);
  final String message;
  @override
  String toString() => message;
}
