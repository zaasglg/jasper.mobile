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
import 'package:jospar/features/workspaces/data/models/workspace_model.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_state.dart';

void main() {
  testWidgets('renders Slack-style messenger and filters conversations', (
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
    expect(find.text('Каналы'), findsOneWidget);
    expect(find.text('общий'), findsOneWidget);

    await tester.tap(find.byKey(const Key('messenger-section-channels')));
    await tester.pumpAndSettle();
    expect(find.text('общий'), findsNothing);
    await tester.tap(find.byKey(const Key('messenger-section-channels')));
    await tester.pumpAndSettle();
    expect(find.text('общий'), findsOneWidget);

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
