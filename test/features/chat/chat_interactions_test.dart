import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/chat/data/models/chat_conversation_model.dart';
import 'package:jospar/features/chat/data/models/chat_message_model.dart';
import 'package:jospar/features/chat/data/models/chat_interaction_models.dart';
import 'package:jospar/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:jospar/features/chat/data/thread_typing_controller.dart';
import 'package:jospar/features/chat/domain/repositories/chat_repository.dart';
import 'package:jospar/features/chat/presentation/cubit/conversation_cubit.dart';
import 'package:jospar/features/chat/presentation/widgets/message_interactions.dart';
import 'package:jospar/features/chat/presentation/widgets/channel_avatar.dart';
import 'package:jospar/features/chat/presentation/widgets/message_actions.dart';
import 'package:jospar/core/widgets/user_avatar.dart';
import 'package:jospar/features/chat/presentation/screens/conversation_screen.dart';

const source = ChatConversationModel(
  id: 'channel',
  threadId: 'channel',
  title: 'Source',
  isChannel: true,
);
const target = ChatConversationModel(
  id: 'other',
  threadId: 'other',
  title: 'Другой чат',
  isChannel: true,
);
Map<String, dynamic> payload({
  String text = 'Сообщение',
  bool pinned = false,
}) => {
  'id': 'm',
  'threadId': 'channel',
  'text': text,
  'createdAt': '2026-10-31T10:00:00Z',
  'user': {'id': 'peer', 'name': 'Коллега'},
  'pinned': pinned,
  'reactions': [
    {
      'emoji': '👍',
      'count': 2,
      'reacted': true,
      'authors': ['Коллега', 'Я'],
    },
  ],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'selected_workspace_id': 'w',
    }),
  );
  ChatRepositoryImpl repository(_Adapter adapter) => ChatRepositoryImpl(
    Dio()..httpClientAdapter = adapter,
    const WorkspaceSelectionStorage(FlutterSecureStorage()),
  );
  test('message pin/reactions round trip and quote body parse', () {
    final message = ChatMessageModel.fromJson(
      payload(text: '↩ @Коллега: «Оригинал»\n\nОтвет', pinned: true),
    );
    expect(message.quote?.body, 'Ответ');
    expect(message.quote?.author, 'Коллега');
    expect(message.pinned, true);
    expect(message.reactions.single.count, 2);
    expect(ChatMessageModel.fromJson(message.toJson()), message);
    expect(message.copyWith(text: 'Edit').reactions, message.reactions);
  });
  test(
    'pin, emoji toggle and typing match existing server contracts',
    () async {
      final adapter = _Adapter();
      final repo = repository(adapter);
      final pinned = await repo.togglePin('m');
      expect(pinned.pinned, true);
      expect(adapter.requests.last.path, 'messages/m/pin');
      expect(adapter.requests.last.method, 'POST');
      final reacted = await repo.react('m', '👍');
      expect(reacted.reactions.single.reacted, true);
      expect(adapter.requests.last.data, {'emoji': '👍'});
      expect((await repo.typing('channel', 'w')).single.name, 'Коллега');
      expect(adapter.requests.last.queryParameters, {
        'threadId': 'channel',
        'workspaceId': 'w',
      });
      await repo.updateTyping('channel', 'w', false);
      expect(adapter.requests.last.data, {
        'threadId': 'channel',
        'workspaceId': 'w',
        'typing': false,
      });
    },
  );
  test(
    'reply wire format matches web and failed send preserves reply',
    () async {
      final adapter = _Adapter();
      final repo = repository(adapter);
      final cubit = ConversationCubit(repo, source);
      final original = ChatMessageModel.fromJson(payload());
      cubit.selectReply(original);
      adapter.fail = true;
      expect(await cubit.send('Ответ'), false);
      expect(cubit.state.replyTo, original);
      adapter.fail = false;
      expect(await cubit.send('Ответ'), true);
      expect(
        adapter.requests
            .where((r) => r.path == 'messages' && r.method == 'POST')
            .last
            .data['text'],
        '↩ @Коллега: «Сообщение»\n\nОтвет',
      );
      expect(cubit.state.replyTo, isNull);
      await cubit.close();
    },
  );
  test('forward uses selected thread and preserves file attachment', () async {
    final adapter = _Adapter();
    final repo = repository(adapter);
    final file = ChatMessageModel.fromJson(
      payload(text: '📎 report.pdf · 1 КБ'),
    );
    await repo.forwardMessage(file, target);
    expect(
      adapter.requests.any((r) => r.path == 'messages/m/attachment'),
      true,
    );
    final sent = adapter.requests.last.data;
    expect(sent['threadId'], 'other');
    expect(sent['workspaceId'], 'w');
    expect(sent['mention'], 'data:application/pdf;base64,AA==');
    expect(sent['text'], file.text);
    await repo.forwardMessage(ChatMessageModel.fromJson(payload()), target);
    expect(adapter.requests.last.data['text'], '↪ Сообщение');
  });

  test('forward preserves stored voice URL and audio metadata', () async {
    final adapter = _Adapter();
    final repo = repository(adapter);
    const url =
        'https://storage.example/voice.m4a?signature=one#orbita-r2=reference';
    await repo.forwardMessage(
      ChatMessageModel.fromJson({
        ...payload(text: ''),
        'kind': 'AUDIO',
        'transcript': url,
        'duration': 7,
      }),
      target,
    );
    final sent = adapter.requests.last.data;
    expect(sent['kind'], 'AUDIO');
    expect(sent['threadId'], 'other');
    expect(sent['transcript'], url);
    expect(sent['duration'], 7);
  });
  test('server rejection retains previous reactions and pin', () async {
    final adapter = _Adapter();
    final cubit = ConversationCubit(repository(adapter), source);
    await cubit.load();
    final before = cubit.state.messages.single;
    adapter.fail = true;
    expect(await cubit.interact('m'), false);
    expect(cubit.state.messages.single, before);
    expect(cubit.state.isSending, false);
    adapter.fail = false;
    expect(await cubit.interact('m'), true);
    expect(cubit.state.messages.single.pinned, true);
    await cubit.close();
  });
  testWidgets(
    'typing throttles start, stops after idle and clears when hidden',
    (t) async {
      final repo = _TypingRepo();
      final typing = ThreadTypingController(
        repo,
        'channel',
        now: t.binding.clock.now,
      );
      typing.setActive(true);
      await t.pump();
      expect(typing.users.single.name, 'Коллега');
      typing.textChanged('a');
      typing.textChanged('ab');
      await t.pump();
      expect(repo.updates, [true]);
      await t.pump(const Duration(seconds: 2));
      typing.textChanged('abc');
      await t.pump();
      expect(repo.updates, [true, true]);
      await t.pump(const Duration(seconds: 4));
      await t.pump();
      expect(repo.updates.last, false);
      typing.textChanged('x');
      await t.pump();
      typing.setActive(false);
      await t.pump();
      expect(typing.users, isEmpty);
      expect(repo.updates.last, false);
      final loads = repo.loads;
      await t.pump(const Duration(seconds: 10));
      expect(repo.loads, loads);
      typing.dispose();
    },
  );
  testWidgets(
    'delayed typing start never overtakes stop and uses captured workspace',
    (t) async {
      final repo = _TypingRepo()..gate = Completer<void>();
      final typing = ThreadTypingController(repo, 'channel');
      typing.setActive(true);
      await t.pump();
      typing.textChanged('a');
      await t.pump();
      typing.setActive(false);
      repo.workspace = 'other';
      await t.pump();
      expect(repo.updates, [true]);
      repo.gate!.complete();
      await t.pump();
      expect(repo.updates, [true, false]);
      expect(repo.scopes, ['w', 'w']);
      typing.dispose();
    },
  );
  testWidgets('stale presence expires even when next polling request stalls', (
    t,
  ) async {
    final repo = _TypingRepo();
    final typing = ThreadTypingController(repo, 'channel');
    typing.setActive(true);
    await t.pump();
    expect(typing.users, isNotEmpty);
    repo.readGate = Completer<List<ChatTypingUser>>();
    await t.pump(const Duration(seconds: 7));
    expect(typing.users, isEmpty);
    typing.dispose();
    repo.readGate!.complete([]);
    await t.pump();
  });
  for (final expanded in [false, true]) {
    testWidgets(
      'long press opens floating reactions and ${expanded ? "plus opens more emoji" : "quick emoji sends immediately"}',
      (t) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        t.view.physicalSize = const Size(320, 568);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final adapter = _Adapter();
        final cubit = ConversationCubit(repository(adapter), source);
        await t.runAsync(() => cubit.load());
        await t.pumpWidget(
          MaterialApp(
            home: BlocProvider.value(
              value: cubit,
              child: const ConversationScreen(conversation: source),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(
          t.getTopLeft(find.byKey(const ValueKey('reaction-chip-m-👍'))).dy,
          lessThan(
            t.getBottomLeft(find.byKey(const Key('message-bubble-m'))).dy,
          ),
        );
        await t.longPress(find.byKey(const Key('message-bubble-m')));
        await t.pumpAndSettle();
        expect(
          find.byKey(const Key('message-quick-reactions')),
          findsOneWidget,
        );
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('Ответить'), findsOneWidget);
        if (expanded) {
          await t.tap(find.byKey(const Key('message-more-reactions')));
          await t.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(find.text('Выберите реакцию'), findsOneWidget);
        }
        await t.tap(
          expanded
              ? find.byKey(const ValueKey('reaction-picker-🎉'))
              : find.byKey(const ValueKey('message-react-👍')),
        );
        await t.pumpAndSettle();
        if (cubit.state.isSending) {
          await t.runAsync(() => cubit.stream.firstWhere((s) => !s.isSending));
        }
        await t.pumpAndSettle();
        expect(
          adapter.requests.where((r) => r.path.endsWith('/react')).last.data,
          {'emoji': expanded ? '🎉' : '👍'},
        );
        expect(find.byKey(const Key('message-quick-reactions')), findsNothing);
        expect(cubit.state.isSending, isFalse);
        final previous = cubit.state.messages.single.reactions;
        await t.longPress(find.byKey(const Key('message-bubble-m')));
        await t.pumpAndSettle();
        final writes = adapter.requests
            .where((r) => r.path.endsWith('/react'))
            .length;
        await t.tapAt(const Offset(2, 2));
        await t.pumpAndSettle();
        expect(
          adapter.requests.where((r) => r.path.endsWith('/react')).length,
          writes,
        );
        await t.longPress(find.byKey(const Key('message-bubble-m')));
        await t.pumpAndSettle();
        adapter.fail = true;
        await t.tap(find.byKey(const ValueKey('message-react-❤️')));
        await t.pumpAndSettle();
        if (cubit.state.isSending) {
          await t.runAsync(() => cubit.stream.firstWhere((s) => !s.isSending));
        }
        await t.pumpAndSettle();
        expect(cubit.state.messages.single.reactions, previous);
        expect(cubit.state.error, isNotNull);
        await t.longPress(find.byKey(const Key('message-bubble-m')));
        await t.pumpAndSettle();
        await t.tap(find.text('Ответить'));
        await t.pumpAndSettle();
        expect(cubit.state.replyTo?.id, 'm');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await cubit.close();
      },
    );
  }

  testWidgets(
    'single reaction is a compact emoji pill without a redundant count',
    (t) async {
      final adapter = _Adapter();
      final cubit = ConversationCubit(repository(adapter), source);
      final message = ChatMessageModel.fromJson({
        ...payload(),
        'reactions': const [
          {'emoji': '👍', 'count': 1, 'reacted': true},
        ],
      });
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: BlocProvider.value(
            value: cubit,
            child: Scaffold(
              body: Center(child: MessageReactionBar(message: message)),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('1'), findsNothing);
      expect(
        t.getSize(find.byKey(const ValueKey('reaction-chip-m-👍'))).width,
        lessThan(40),
      );
      expect(
        t.getSize(find.byKey(const ValueKey('reaction-chip-m-👍'))).height,
        lessThan(32),
      );
      final groupedMessage = ChatMessageModel.fromJson({
        ...payload(),
        'reactions': const [
          {'emoji': '👍', 'count': 1, 'reacted': true},
          {'emoji': '😮', 'count': 2, 'reacted': false},
        ],
      });
      await t.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: Scaffold(
              body: Center(child: MessageReactionBar(message: groupedMessage)),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final first = t.getRect(find.byKey(const ValueKey('reaction-chip-m-👍')));
      final second = t.getRect(
        find.byKey(const ValueKey('reaction-chip-m-😮')),
      );
      expect(second.left, lessThan(first.right));
      expect(second.left, greaterThan(first.left));
      expect(find.byKey(const ValueKey('message-reactions-m')), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await cubit.close();
    },
  );

  testWidgets('reaction chip toggles using the selected emoji', (t) async {
    final adapter = _Adapter();
    final cubit = ConversationCubit(repository(adapter), source);
    await t.runAsync(() => cubit.load());
    await t.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: MessageReactionBar(message: cubit.state.messages.single),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('reaction-chip-m-👍')));
    await t.pumpAndSettle();
    expect(adapter.requests.last.path, 'messages/m/react');
    expect(adapter.requests.last.data, {'emoji': '👍'});
    await t.pumpWidget(const SizedBox());
    await cubit.close();
  });
  testWidgets('pinned bar opens the original message', (t) async {
    String? selected;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinnedMessagesBar(
            messages: [ChatMessageModel.fromJson(payload(pinned: true))],
            onSelect: (id) => selected = id,
          ),
        ),
      ),
    );
    await t.tap(find.text('Закреплённые'));
    expect(selected, 'm');
    await t.pumpWidget(const SizedBox());
  });
  for (final mode in ['audio', 'video']) {
    testWidgets('$mode call disables copy and forward and never exposes JSON', (
      t,
    ) async {
      final raw = jsonEncode({
        'callId': 'call',
        'mode': mode,
        'status': 'ended',
      });
      final adapter = _Adapter()..text = raw;
      final cubit = ConversationCubit(repository(adapter), source);
      await t.runAsync(() => cubit.load());
      final message = cubit.state.messages.single;
      expect(message.canCopyText, false);
      expect(message.canEditText, false);
      expect(message.canForward, false);
      expect(message.preview, isNot(contains('callId')));
      final before = adapter.requests.length;
      expect(await cubit.forward(message, target), false);
      expect(
        await cubit.messageAction(message.id, 'edit', text: 'changed'),
        false,
      );
      expect(adapter.requests.length, before);
      await t.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showMessageActions(context, message, true),
                  child: const Text('Actions'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Actions'));
      await t.pumpAndSettle();
      for (final label in ['Копировать текст', 'Переслать']) {
        final tile = find.ancestor(
          of: find.text(label),
          matching: find.byType(ListTile),
        );
        expect(t.widget<ListTile>(tile).enabled, false);
        expect(t.widget<ListTile>(tile).onTap, isNull);
      }
      expect(find.text('Редактировать'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await cubit.close();
    });
  }
  test('only ordinary nonempty text can be copied and edited', () {
    expect(ChatMessageModel.fromJson(payload()).canCopyText, true);
    expect(ChatMessageModel.fromJson(payload(text: ' ')).canCopyText, false);
    for (final kind in ['AUDIO', 'VIDEO_MSG', 'FILE', 'POLL']) {
      final message = ChatMessageModel.fromJson({...payload(), 'kind': kind});
      expect(message.canCopyText, false);
      expect(message.canEditText, false);
      expect(message.canForward, true);
    }
  });
  testWidgets(
    'forward sheet groups channels, nests children and shows avatars',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final adapter = _Adapter()
        ..channels = [
          {'id': 'child', 'name': 'Подканал Alpha', 'parentId': 'parent'},
          {'id': 'parent', 'name': 'Команда'},
        ]
        ..users = [
          {'id': 'person', 'name': 'Сотрудник'},
        ];
      final cubit = ConversationCubit(repository(adapter), source);
      await t.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showForwardMessage(
                    context,
                    ChatMessageModel.fromJson(payload()),
                  ),
                  child: const Text('Forward'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Forward'));
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(ChannelAvatar), findsNWidgets(2));
      expect(find.byType(UserAvatar), findsOneWidget);
      expect(find.text('Каналы'), findsOneWidget);
      expect(find.text('Личные сообщения'), findsOneWidget);
      final parent = find.byKey(const ValueKey('forward-target-parent'));
      final child = find.byKey(const ValueKey('forward-target-child'));
      expect(t.getTopLeft(child).dy, greaterThan(t.getTopLeft(parent).dy));
      expect(t.getTopLeft(child).dx, greaterThan(t.getTopLeft(parent).dx));
      expect(find.text('Подканал · Команда'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Alpha');
      await t.pumpAndSettle();
      expect(parent, findsOneWidget);
      expect(child, findsOneWidget);
      expect(find.text('Сотрудник'), findsNothing);
      await t.enterText(find.byType(TextField), 'не существует');
      await t.pumpAndSettle();
      expect(find.text('Чаты не найдены'), findsOneWidget);
      await t.tap(find.byTooltip('Отмена'));
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await cubit.close();
    },
  );
  testWidgets('forward dialog keeps target available after a rejected send', (
    t,
  ) async {
    final adapter = _Adapter();
    final cubit = ConversationCubit(repository(adapter), source);
    await t.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showForwardMessage(
                  context,
                  ChatMessageModel.fromJson(payload()),
                ),
                child: const Text('Forward'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Forward'));
    await t.pumpAndSettle();
    expect(find.text('Другой чат'), findsOneWidget);
    adapter.fail = true;
    await t.runAsync(() async {
      final completed = cubit.stream.firstWhere(
        (s) => !s.isSending && s.error != null,
      );
      await t.tap(find.text('Другой чат'));
      await completed;
    });
    await t.pumpAndSettle();
    expect(find.text('Переслать сообщение'), findsOneWidget);
    expect(cubit.state.isSending, false);
    expect(cubit.state.error, isNotNull);
    await t.tap(find.byTooltip('Отмена'));
    await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox());
    await cubit.close();
  });
  testWidgets(
    'pinned message opens its source and quote renders in the conversation',
    (t) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final adapter = _Adapter()..text = '↩ @Коллега: «Оригинал»\n\nОтвет';
      final cubit = ConversationCubit(repository(adapter), source);
      await t.runAsync(() => cubit.load());
      await t.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const ConversationScreen(conversation: source),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Оригинал'), findsOneWidget);
      cubit.selectReply(cubit.state.messages.single);
      expect(cubit.state.replyTo?.authorName, 'Коллега');
      await t.pumpAndSettle();
      expect(find.text('Ответ: Коллега'), findsOneWidget);
      await t.tap(find.byTooltip('Отменить ответ'));
      await t.pump();
      expect(cubit.state.replyTo, isNull);
      await t.pumpWidget(const SizedBox());
      await cubit.close();
    },
  );
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool fail = false;
  String text = 'Сообщение';
  List<Map<String, dynamic>> channels = [
    {'id': 'other', 'name': 'Другой чат'},
  ];
  List<Map<String, dynamic>> users = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    if (fail) {
      return ResponseBody.fromString(
        '{"message":"Нет доступа"}',
        403,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    dynamic result;
    if (options.path == 'users/me') {
      result = {'id': 'me'};
    } else if (options.path == 'channels') {
      result = channels;
    } else if (options.path == 'users/messenger-candidates') {
      result = users;
    } else if (options.path == 'messages/threads') {
      result = [];
    } else if (options.path == 'messages/typing') {
      result = options.method == 'GET'
          ? [
              {'userId': 'peer', 'name': 'Коллега'},
            ]
          : {'ok': true};
    } else if (options.path.endsWith('/attachment')) {
      result = {'dataUrl': 'data:application/pdf;base64,AA=='};
    } else if (options.path.endsWith('/pin')) {
      result = payload(pinned: true);
    } else if (options.path.endsWith('/react')) {
      result = payload();
    } else if (options.path == 'messages' && options.method == 'GET') {
      result = [payload(text: text)];
    } else if (options.path == 'messages' && options.method == 'POST') {
      result = {
        ...payload(text: options.data['text']),
        ...Map<String, dynamic>.from(options.data as Map),
      };
    } else {
      result = {'ok': true};
    }
    return ResponseBody.fromString(
      jsonEncode(result),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _TypingRepo implements ChatInteractionRepository {
  final updates = <bool>[], scopes = <String>[];
  String workspace = 'w';
  int loads = 0;
  Completer<void>? gate;
  Completer<List<ChatTypingUser>>? readGate;
  @override
  Future<String> interactionWorkspaceId() async => workspace;
  @override
  Future<List<ChatTypingUser>> typing(
    String threadId,
    String workspaceId,
  ) async {
    loads++;
    return readGate?.future ??
        [const ChatTypingUser(userId: 'peer', name: 'Коллега')];
  }

  @override
  Future<void> updateTyping(
    String threadId,
    String workspaceId,
    bool value,
  ) async {
    updates.add(value);
    scopes.add(workspaceId);
    if (value) await gate?.future;
  }

  @override
  Future<ChatMessageModel> togglePin(String id) async =>
      ChatMessageModel.fromJson(payload(pinned: true));
  @override
  Future<ChatMessageModel> react(String id, String emoji) async =>
      ChatMessageModel.fromJson(payload());
  @override
  Future<ChatMessageModel> forwardMessage(
    ChatMessageModel message,
    ChatConversationModel target,
  ) async => message;
}
