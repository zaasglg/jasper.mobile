import 'package:flutter/material.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/profile/domain/repositories/profile_repository.dart';
import 'package:jospar/features/profile/data/models/user_profile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/chat/data/models/chat_conversation_model.dart';
import 'package:jospar/features/chat/data/models/chat_message_model.dart';
import 'package:jospar/features/chat/domain/repositories/chat_repository.dart';
import 'package:jospar/features/chat/presentation/cubit/conversation_cubit.dart';
import 'package:jospar/features/chat/presentation/screens/conversation_screen.dart';

void main() {
  testWidgets('renders a shared task link as a board card inside the chat', (
    tester,
  ) async {
    const chat = ChatConversationModel(
      id: 'general',
      threadId: 'general',
      title: 'Общий',
      isChannel: true,
    );
    final repository = _FakeChatRepository(
      messages: [
        ChatMessageModel(
          id: 'task-message',
          threadId: 'general',
          authorId: 'user',
          authorName: 'Автор',
          text:
              '[ПР-96: Batyrkhan exam](https://jospar.me/tasks?view=kanban&taskId=task&project=project)',
          createdAt: DateTime(2026, 10, 5),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => ConversationCubit(repository, chat)..load(),
          child: const ConversationScreen(conversation: chat),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shared-task-task')), findsOneWidget);
    expect(find.text('ПР-96'), findsOneWidget);
    expect(find.text('Batyrkhan exam'), findsOneWidget);
    expect(find.textContaining('https://jospar.me/tasks'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('own messages align right and mentions open a user card', (
    tester,
  ) async {
    const conversation = ChatConversationModel(
      id: 'channel',
      threadId: 'channel',
      title: 'Общий',
      isChannel: true,
    );
    final repository = _FakeChatRepository(
      messages: [
        ChatMessageModel(
          id: 'other',
          threadId: 'channel',
          authorId: 'other',
          authorName: 'Данияр',
          text: 'Привет',
          createdAt: DateTime(2026, 10, 5, 12),
        ),
        ChatMessageModel(
          id: 'mine',
          threadId: 'channel',
          authorId: 'me',
          authorName: 'Ердаулет',
          text: '@[Данияр] проверка связи',
          createdAt: DateTime(2026, 10, 5, 13),
        ),
      ],
      people: const [
        ChatConversationModel(
          id: 'other',
          threadId: 'direct',
          title: 'Данияр',
          isChannel: false,
        ),
      ],
    );
    sl.registerSingleton<ProfileRepository>(_ProfileRepository());
    sl.registerSingleton<ChatRepository>(repository);
    addTearDown(() async {
      await sl.unregister<ProfileRepository>();
      await sl.unregister<ChatRepository>();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => ConversationCubit(repository, conversation)..load(),
          child: const ConversationScreen(conversation: conversation),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final incoming = tester.getRect(
      find.byKey(const Key('message-bubble-other')),
    );
    final outgoing = tester.getRect(
      find.byKey(const Key('message-bubble-mine')),
    );
    expect(outgoing.right, greaterThan(incoming.right));
    expect(outgoing.left, greaterThan(incoming.left));
    expect(find.byType(ClipOval), findsWidgets);
    await tester.tap(find.byKey(const Key('mention-mine-0')));
    await tester.pumpAndSettle();
    expect(find.text('Написать сообщение'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final isChannel in [true, false]) {
    testWidgets(
      'opens ${isChannel ? 'channel' : 'direct chat'} at the newest message',
      (tester) async {
        tester.view.physicalSize = const Size(390, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final conversation = ChatConversationModel(
          id: 'chat',
          threadId: 'chat',
          title: 'Команда',
          isChannel: isChannel,
        );
        final messages = List.generate(
          40,
          (index) => ChatMessageModel(
            id: 'm$index',
            threadId: 'chat',
            authorId: 'user',
            authorName: 'Автор',
            text: 'Сообщение $index',
            createdAt: DateTime(2026, 10, 5, 12, index),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider(
              create: (_) => ConversationCubit(
                _FakeChatRepository(messages: messages.reversed.toList()),
                conversation,
              )..load(),
              child: ConversationScreen(conversation: conversation),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Сообщение 39'), findsOneWidget);
        expect(find.text('Сообщение 0'), findsNothing);
        expect(
          tester.getTopLeft(find.text('Сообщение 39')).dy,
          greaterThan(tester.getTopLeft(find.text('Сообщение 38')).dy),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('renders conversation and sends a message', (tester) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const conversation = ChatConversationModel(
      id: 'general',
      threadId: 'general',
      title: 'общий',
      isChannel: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) =>
              ConversationCubit(_FakeChatRepository(), conversation)..load(),
          child: const ConversationScreen(conversation: conversation),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('# общий'), findsOneWidget);
    expect(find.text('Это начало канала #общий'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('conversation-composer')),
      'Новое сообщение',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('conversation-send')));
    await tester.pumpAndSettle();

    expect(find.text('Новое сообщение'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders legacy call payload as a call card', (tester) async {
    const conversation = ChatConversationModel(
      id: 'general',
      threadId: 'general',
      title: 'general',
      isChannel: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => ConversationCubit(
            _FakeChatRepository(
              messages: <ChatMessageModel>[
                ChatMessageModel.fromJson(const <String, dynamic>{
                  'id': 'call-1',
                  'threadId': 'general',
                  'authorName': 'RBV',
                  'createdAt': '2026-09-19T11:10:00Z',
                  'text':
                      '{"callId":"c1","mode":"video","status":"ended",'
                      '"title":"Конференция general","durationSec":23}',
                }),
              ],
            ),
            conversation,
          )..load(),
          child: const ConversationScreen(conversation: conversation),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('call-message-call-1')), findsOneWidget);
    expect(find.text('Видеозвонок завершён'), findsOneWidget);
    expect(find.text('Конференция general · 23 сек.'), findsOneWidget);
    expect(find.textContaining('"callId"'), findsNothing);
  });

  testWidgets('renders a file message as an attachment card', (tester) async {
    const conversation = ChatConversationModel(
      id: 'general',
      threadId: 'general',
      title: 'general',
      isChannel: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => ConversationCubit(
            _FakeChatRepository(
              messages: <ChatMessageModel>[
                ChatMessageModel.fromJson(const <String, dynamic>{
                  'id': 'file-1',
                  'threadId': 'general',
                  'authorName': 'RBV',
                  'createdAt': '2026-09-19T15:10:00Z',
                  'kind': 'FILE',
                  'text': '📎 Текстовый документ.txt · 4 КБ',
                }),
              ],
            ),
            conversation,
          )..load(),
          child: const ConversationScreen(conversation: conversation),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('file-attachment-file-1')), findsOneWidget);
    expect(find.text('Текстовый документ.txt'), findsOneWidget);
    expect(find.text('4 КБ'), findsOneWidget);
    expect(find.text('📎 Текстовый документ.txt · 4 КБ'), findsNothing);
  });
}

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({
    this.messages = const <ChatMessageModel>[],
    this.people = const <ChatConversationModel>[],
  });
  final List<ChatConversationModel> people;

  final List<ChatMessageModel> messages;

  @override
  Future<ChatConversationModel> createChannel({
    required String name,
    String? parentId,
  }) => throw UnimplementedError();

  @override
  Future<List<ChatConversationModel>> getConversations() async => people;

  @override
  Future<List<ChatMessageModel>> getMessages(String threadId) async => messages;

  @override
  Future<ChatMessageModel> sendMessage({
    required ChatConversationModel conversation,
    required String text,
    ChatMessageKind kind = ChatMessageKind.text,
    String? transcript,
    String? mention,
    int? duration,
  }) async => ChatMessageModel(
    id: 'message-1',
    threadId: conversation.threadId,
    authorId: 'me',
    authorName: 'Вы',
    text: text,
    createdAt: DateTime(2026),
  );
}

class _ProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile> getCurrentUser() async =>
      const UserProfile(id: 'me', name: 'Ердаулет', email: 'me@example.test');
}
