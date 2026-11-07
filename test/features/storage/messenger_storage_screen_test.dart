import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/chat/data/models/chat_conversation_model.dart';
import 'package:jospar/features/chat/domain/repositories/chat_repository.dart';
import 'package:jospar/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:jospar/features/storage/data/storage_models.dart';
import 'package:jospar/features/storage/presentation/messenger_storage_screen.dart';

void main() {
  testWidgets(
    'messenger storage opens the chosen thread and returns to its source message',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'selected_workspace_id': 'workspace',
      });
      sl.registerSingleton<WorkspaceSelectionStorage>(
        const WorkspaceSelectionStorage(FlutterSecureStorage()),
      );
      addTearDown(() => sl.reset());
      StorageScope? scope;
      String? focusedId;
      ChatConversationModel? target;
      final router = GoRouter(
        initialLocation: '/files',
        routes: [
          GoRoute(
            path: '/files',
            builder: (_, _) => BlocProvider(
              create: (_) => ChatCubit(_Chats())..load(),
              child: const MessengerStorageScreen(),
            ),
          ),
          GoRoute(
            path: '/storage',
            builder: (context, state) {
              scope = state.extra! as StorageScope;
              return Scaffold(
                body: TextButton(
                  onPressed: () => context.pop('source-message'),
                  child: const Text('Открыть источник'),
                ),
              );
            },
          ),
          GoRoute(
            path: '/messenger/:id',
            builder: (_, state) {
              focusedId = state.uri.queryParameters['messageId'];
              target = state.extra! as ChatConversationModel;
              return const Scaffold(body: Text('Исходная переписка'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('общий'), findsOneWidget);
      expect(find.text('Алия'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Алия');
      await tester.pumpAndSettle();
      expect(find.text('общий'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'Алия'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(scope?.id, 'dm:me:user');
      expect(scope?.workspaceId, 'workspace');
      expect(scope?.source, StorageSource.chat);
      await tester.tap(find.text('Открыть источник'));
      await tester.pumpAndSettle();
      expect(find.text('Исходная переписка'), findsOneWidget);
      expect(focusedId, 'source-message');
      expect(target?.id, 'user');
      expect(tester.takeException(), isNull);
    },
  );
}

class _Chats implements ChatRepository {
  @override
  Future<List<ChatConversationModel>> getConversations() async => const [
    ChatConversationModel(
      id: 'channel',
      threadId: 'thread-channel',
      title: 'общий',
      isChannel: true,
    ),
    ChatConversationModel(
      id: 'user',
      threadId: 'dm:me:user',
      title: 'Алия',
      isChannel: false,
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
