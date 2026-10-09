import '../../data/models/chat_conversation_model.dart';
import '../../data/models/chat_message_model.dart';

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

class ChatException implements Exception {
  const ChatException(this.message);
  final String message;
  @override
  String toString() => message;
}
