import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jospar/features/chat/data/models/chat_conversation_model.dart';
import 'package:jospar/features/chat/data/models/chat_message_model.dart';
import 'package:jospar/features/chat/domain/repositories/chat_repository.dart';
import 'package:jospar/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:jospar/features/chat/presentation/cubit/conversation_cubit.dart';
import 'package:jospar/features/chat/presentation/widgets/messenger_refresh_lifecycle.dart';
import 'package:jospar/features/collaboration/data/collaboration_models.dart';

const conversation = ChatConversationModel(
  id: 'dm:a:b',
  threadId: 'dm:a:b',
  title: 'Коллега',
  isChannel: false,
);
ChatMessageModel message(String id) => ChatMessageModel(
  id: id,
  threadId: conversation.threadId,
  authorId: 'b',
  authorName: 'Коллега',
  text: id,
  createdAt: DateTime(2026, 10, 31),
);
void main() {
  testWidgets(
    'chat counts refresh silently, pause and update immediately on return',
    (t) async {
      final repo = _Repository();
      final cubit = ChatCubit(repo);
      cubit.setAutoRefresh(true);
      await t.pump();
      expect((cubit.state as ChatLoaded).conversations.single.unreadCount, 1);
      repo.unread = 3;
      await t.pump(const Duration(seconds: 15));
      await t.pump();
      expect((cubit.state as ChatLoaded).conversations.single.unreadCount, 3);
      cubit.setAutoRefresh(false);
      final count = repo.chatLoads;
      await t.pump(const Duration(seconds: 45));
      expect(repo.chatLoads, count);
      repo.unread = 4;
      cubit.setAutoRefresh(true);
      await t.pump();
      expect((cubit.state as ChatLoaded).conversations.single.unreadCount, 4);
      await cubit.close();
    },
  );
  testWidgets(
    'transient refresh failure preserves history and automatically recovers',
    (t) async {
      final repo = _Repository();
      final cubit = ConversationCubit(repo, conversation);
      cubit.setAutoRefresh(true);
      await t.pump();
      repo.fail = true;
      await t.pump(const Duration(seconds: 10));
      await t.pump();
      expect(cubit.state.messages.single.id, 'one');
      expect(cubit.state.error, isNull);
      expect(cubit.state.isLoading, isFalse);
      repo.fail = false;
      repo.messages.add(message('two'));
      await t.pump(const Duration(seconds: 10));
      await t.pump();
      expect(cubit.state.messages.map((e) => e.id), ['one', 'two']);
      await cubit.close();
    },
  );
  testWidgets(
    'hidden conversation stops polling and does not mark a pending response read',
    (t) async {
      final repo = _Repository()
        ..messageGate = Completer<List<ChatMessageModel>>();
      final cubit = ConversationCubit(repo, conversation);
      cubit.setAutoRefresh(true);
      await t.pump();
      cubit.setAutoRefresh(false);
      repo.messageGate!.complete([message('one')]);
      await t.pump();
      expect(repo.reads, 0);
      final count = repo.messageLoads;
      await t.pump(const Duration(seconds: 30));
      expect(repo.messageLoads, count);
      await cubit.close();
    },
  );
  testWidgets('slow requests never overlap', (t) async {
    final repo = _Repository()
      ..messageGate = Completer<List<ChatMessageModel>>();
    final cubit = ConversationCubit(repo, conversation);
    cubit.setAutoRefresh(true);
    await t.pump(const Duration(seconds: 30));
    expect(repo.messageLoads, 1);
    cubit.setAutoRefresh(false);
    repo.messageGate!.complete([]);
    await t.pump();
    await cubit.close();
  });
  testWidgets('late refresh cannot erase a message sent during that request', (
    t,
  ) async {
    final repo = _Repository();
    final cubit = ConversationCubit(repo, conversation);
    await cubit.load();
    repo.messageGate = Completer<List<ChatMessageModel>>();
    final pending = cubit.load(silent: true);
    expect(await cubit.send('sent'), isTrue);
    repo.messageGate!.complete([message('one')]);
    await pending;
    expect(cubit.state.messages.map((e) => e.id), ['one', 'sent']);
    await cubit.close();
  });
  testWidgets(
    'late previous-workspace responses are discarded and new chat list loads',
    (t) async {
      final repo = _Repository()
        ..chatGate = Completer<List<ChatConversationModel>>();
      final cubit = ChatCubit(repo);
      final pending = cubit.load();
      cubit.invalidate();
      cubit.setAutoRefresh(true);
      final gate = repo.chatGate!;
      repo.chatGate = null;
      repo.unread = 7;
      gate.complete([conversation.copyWith(unreadCount: 99)]);
      await pending;
      await t.pump();
      expect((cubit.state as ChatLoaded).conversations.single.unreadCount, 7);
      await cubit.close();
    },
  );
  testWidgets('unchanged polling does not repeatedly mark the same tail read', (
    t,
  ) async {
    final repo = _Repository();
    final cubit = ConversationCubit(repo, conversation);
    cubit.setAutoRefresh(true);
    await t.pump();
    await t.pump(const Duration(seconds: 10));
    await t.pump();
    expect(repo.reads, 1);
    repo.messages.add(message('two'));
    await t.pump(const Duration(seconds: 10));
    await t.pump();
    expect(repo.reads, 2);
    await cubit.close();
  });
  testWidgets(
    'invalidated conversation rejects stale reads and further sends',
    (t) async {
      final repo = _Repository()
        ..messageGate = Completer<List<ChatMessageModel>>();
      final cubit = ConversationCubit(repo, conversation);
      final pending = cubit.load();
      cubit.invalidate();
      repo.messageGate!.complete([message('old-workspace')]);
      await pending;
      expect(cubit.state.messages, isEmpty);
      expect(await cubit.send('wrong workspace'), isFalse);
      cubit.setAutoRefresh(true);
      await t.pump(const Duration(seconds: 20));
      expect(repo.messageLoads, 1);
      await cubit.close();
    },
  );
  testWidgets('repeated server IDs never duplicate messages during refresh', (
    t,
  ) async {
    final repo = _Repository()..messages.add(message('one'));
    final cubit = ConversationCubit(repo, conversation);
    cubit.setAutoRefresh(true);
    await t.pump();
    await t.pump(const Duration(seconds: 10));
    await t.pump();
    expect(cubit.state.messages.length, 1);
    await cubit.close();
  });
  testWidgets(
    'route cover and app suspension pause refresh; returning resumes it',
    (t) async {
      final repo = _Repository();
      final cubit = ConversationCubit(repo, conversation);
      final router = GoRouter(
        initialLocation: '/messenger/dm:a:b',
        routes: [
          GoRoute(path: '/messenger/:id', builder: (_, _) => _Harness(cubit)),
          GoRoute(
            path: '/other',
            builder: (_, _) => const Scaffold(body: Text('Other')),
          ),
        ],
      );
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      expect(repo.messageLoads, greaterThan(0));
      unawaited(router.push('/other'));
      await t.pumpAndSettle();
      final hiddenCount = repo.messageLoads;
      await t.pump(const Duration(seconds: 20));
      expect(repo.messageLoads, hiddenCount);
      router.pop();
      await t.pumpAndSettle();
      expect(repo.messageLoads, greaterThan(hiddenCount));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final suspended = repo.messageLoads;
      await t.pump(const Duration(seconds: 20));
      expect(repo.messageLoads, suspended);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(repo.messageLoads, greaterThan(suspended));
      await t.pumpWidget(const SizedBox());
      await cubit.close();
      router.dispose();
    },
  );
}

class _Harness extends StatefulWidget {
  const _Harness(this.cubit);
  final ConversationCubit cubit;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness>
    with MessengerRefreshLifecycle<_Harness> {
  @override
  String get messengerRefreshPath => '/messenger/dm:a:b';
  @override
  void setMessengerRefresh(bool active) => widget.cubit.setAutoRefresh(active);
  @override
  void invalidateMessenger() => widget.cubit.invalidate();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Chat'));
}

class _Repository implements ChatRepository, ChatActionsRepository {
  int chatLoads = 0, messageLoads = 0, unread = 1, reads = 0;
  bool fail = false;
  final messages = [message('one')];
  Completer<List<ChatConversationModel>>? chatGate;
  Completer<List<ChatMessageModel>>? messageGate;
  @override
  Future<List<ChatConversationModel>> getConversations() async {
    chatLoads++;
    if (fail) throw const ChatException('offline');
    return chatGate?.future ?? [conversation.copyWith(unreadCount: unread)];
  }

  @override
  Future<List<ChatMessageModel>> getMessages(String threadId) async {
    messageLoads++;
    if (fail) throw const ChatException('offline');
    return messageGate?.future ?? [...messages];
  }

  @override
  Future<ChatMessageModel> sendMessage({
    required ChatConversationModel conversation,
    required String text,
    ChatMessageKind kind = ChatMessageKind.text,
    String? transcript,
    String? mention,
    int? duration,
  }) async => message('sent');
  @override
  Future<void> markRead(String threadId) async {
    reads++;
  }

  @override
  Future<ChatConversationModel> createChannel({
    required String name,
    String? parentId,
  }) async => conversation;
  @override
  Future<void> toggleFavorite(String id) async {}
  @override
  Future<void> editMessage(String id, String text) async {}
  @override
  Future<void> deleteMessage(String id) async {}
  @override
  Future<void> renameChannel(String id, String name) async {}
  @override
  Future<void> leaveChannel(String id) async {}
  @override
  Future<void> deleteChannel(String id) async {}
  @override
  Future<List<SpaceMember>> channelMembers(String id) async => [];
  @override
  Future<void> setChannelMembers(String id, List<String> users) async {}
}
