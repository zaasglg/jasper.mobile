import 'package:jospar/core/theme/app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:jospar/features/chat/data/models/chat_message_preview_model.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_app_bar.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/chat/data/models/chat_conversation_model.dart';
import 'package:jospar/features/chat/data/models/chat_message_model.dart';
import 'package:jospar/features/chat/domain/repositories/chat_repository.dart';
import 'package:jospar/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:jospar/features/chat/presentation/screens/chat_screen.dart';
import 'package:jospar/features/workspaces/domain/entities/workspace_model.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_state.dart';

void main() {
  testWidgets('dashboard header icons follow the dark palette', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<WorkspaceCubit>(create: (_) => _Workspace()),
            BlocProvider<ProfileCubit>(create: (_) => _Profile()),
          ],
          child: const Scaffold(appBar: DashboardAppBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final icon in [LucideIcons.search, LucideIcons.bell]) {
      final widget = tester.widget<Icon>(find.byIcon(icon));
      expect(widget.color, const AppPalette(true).ink);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders Telegram-style folders and filters conversations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ChatCubit>(
              create: (_) => ChatCubit(_FakeChatRepository())..load(),
            ),
            BlocProvider<WorkspaceCubit>(create: (_) => _Workspace()),
            BlocProvider<ProfileCubit>(create: (_) => _Profile()),
          ],
          child: const ChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DashboardAppBar), findsOneWidget);
    expect(find.byKey(const Key('dashboard-ai-icon')), findsOneWidget);
    expect(find.text('Цифровизация'), findsOneWidget);
    expect(find.text('JOSPAR.ME'), findsNothing);
    expect(find.byKey(const Key('messenger-search')), findsOneWidget);
    expect(find.text('Каналы'), findsNWidgets(2));
    expect(find.text('общий'), findsOneWidget);
    expect(find.text('Дизайн продукта'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('channel-expand-1')));
    await tester.pumpAndSettle();
    expect(find.text('Дизайн продукта'), findsOneWidget);
    final chatContext = tester.element(find.byType(ChatScreen));
    await chatContext.read<ChatCubit>().load(silent: true);
    await tester.pumpAndSettle();
    expect(find.text('Дизайн продукта'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('channel-expand-1')));
    await tester.pumpAndSettle();
    expect(find.text('Дизайн продукта'), findsNothing);
    // Searching must find a child even when its parent is collapsed.
    await tester.enterText(find.byKey(const Key('messenger-search')), 'Дизайн');
    await tester.pumpAndSettle();
    expect(find.text('Дизайн продукта'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('messenger-search')), '');
    await tester.pumpAndSettle();
    expect(find.text('Дизайн продукта'), findsNothing);
    expect(find.text('Анна: План на сегодня согласован'), findsOneWidget);
    expect(find.byKey(const Key('messenger-section-channels')), findsOneWidget);
    await tester.tap(find.byKey(const Key('messenger-section-channels')));
    await tester.pumpAndSettle();
    expect(find.text('общий'), findsNothing);
    expect(find.text('Личные сообщения'), findsOneWidget);
    await tester.tap(find.byKey(const Key('messenger-section-channels')));
    await tester.pumpAndSettle();
    expect(find.text('общий'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('messenger-folder-people')),
    );
    await tester.tap(find.byKey(const Key('messenger-folder-people')));
    await tester.pumpAndSettle();
    expect(find.text('общий'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('messenger-folder-channels')),
    );
    await tester.tap(find.byKey(const Key('messenger-folder-channels')));
    await tester.pumpAndSettle();
    expect(find.text('общий'), findsOneWidget);
    expect(find.text('Анна Садыкова'), findsNothing);
    expect(find.text('Подканал · общий'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('channel-expand-1')));
    await tester.pumpAndSettle();
    expect(find.text('Подканал · общий'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('messenger-folder-all')));
    await tester.tap(find.byKey(const Key('messenger-folder-all')));
    await tester.pumpAndSettle();
    expect(find.text('Анна Садыкова'), findsOneWidget);
    expect(find.byKey(const Key('forwarded-preview-anna')), findsOneWidget);
    expect(find.text('Вы: translation'), findsOneWidget);
    expect(find.text('Вы: ↪ translation'), findsNothing);
    await tester.tap(find.byKey(const Key('messenger-tools')));
    await tester.pumpAndSettle();
    expect(find.text('Упоминания и реакции'), findsOneWidget);
    expect(find.text('Сохранённое'), findsOneWidget);
    expect(find.text('Кладовка'), findsOneWidget);
    Navigator.of(tester.element(find.text('Сохранённое'))).pop();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('messenger-search')),
      'несуществующий чат',
    );
    await tester.pumpAndSettle();

    expect(find.text('Ничего не найдено'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Workspace extends Cubit<WorkspaceState> implements WorkspaceCubit {
  _Workspace()
    : super(
        const WorkspaceLoaded(
          workspaces: [WorkspaceModel(id: 'w', name: 'Цифровизация')],
          selected: WorkspaceModel(id: 'w', name: 'Цифровизация'),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatRepository implements ChatRepository {
  @override
  Future<ChatConversationModel> createChannel({
    required String name,
    String? parentId,
  }) async => ChatConversationModel(
    id: 'created',
    threadId: 'created',
    title: name,
    isChannel: true,
    parentId: parentId,
  );

  @override
  Future<List<ChatConversationModel>> getConversations() async => const [
    ChatConversationModel(
      id: '1',
      threadId: '1',
      title: 'общий',
      isChannel: true,
    ),
    ChatConversationModel(
      id: 'design',
      threadId: 'design',
      title: 'Дизайн продукта',
      isChannel: true,
      parentId: '1',
    ),
    ChatConversationModel(
      id: 'sales',
      threadId: 'sales',
      title: 'Команда продаж',
      isChannel: true,
      lastMessage: ChatMessagePreviewModel(
        text: 'План на сегодня согласован',
        authorName: 'Анна',
      ),
      unreadCount: 7,
    ),
    ChatConversationModel(
      id: 'anna',
      threadId: 'anna',
      title: 'Анна Садыкова',
      isChannel: false,
      hasThread: true,
      isOnline: true,
      unreadCount: 2,
      lastMessage: ChatMessagePreviewModel(text: '↪ translation', isOwn: true),
    ),
  ];

  @override
  Future<List<ChatMessageModel>> getMessages(String threadId) async => const [];

  @override
  Future<ChatMessageModel> sendMessage({
    required ChatConversationModel conversation,
    required String text,
    ChatMessageKind kind = ChatMessageKind.text,
    String? transcript,
    String? mention,
    int? duration,
  }) => throw UnimplementedError();
}

class _Profile extends Cubit<ProfileState> implements ProfileCubit {
  _Profile() : super(const ProfileInitial());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
