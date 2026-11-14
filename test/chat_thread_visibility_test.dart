import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/chat/data/models/chat_conversation_model.dart';

void main() {
  test('available recipient is not an existing conversation', () {
    final candidate = ChatConversationModel.fromUserJson({
      'id': 'peer',
      'name': 'Коллега',
    }, currentUserId: 'me');
    expect(candidate.threadId, 'dm:me:peer');
    expect(candidate.hasThread, isFalse);
    expect(candidate.copyWith(unreadCount: 0).hasThread, isFalse);
  });
  test('thread from API marks existing conversation', () {
    final conversation = ChatConversationModel.fromUserJson(
      {'id': 'peer', 'name': 'Коллега'},
      currentUserId: 'me',
      thread: {'threadId': 'dm:me:peer'},
    );
    expect(conversation.hasThread, isTrue);
    expect(conversation.copyWith(unreadCount: 2).hasThread, isTrue);
    expect(conversation.toJson()['hasThread'], isTrue);
  });
}
