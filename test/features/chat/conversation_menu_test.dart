import 'package:jospar/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/features/chat/data/models/chat_conversation_model.dart';
import 'package:jospar/features/chat/data/models/chat_message_model.dart';
import 'package:jospar/features/chat/domain/repositories/chat_repository.dart';
import 'package:jospar/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:jospar/features/chat/presentation/screens/chat_screen.dart';
import 'package:jospar/features/collaboration/domain/entities/space_member.dart';
import 'package:jospar/features/workspaces/domain/entities/workspace_model.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_state.dart';

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

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<ChatCubit> mount(WidgetTester t, _Repo repo) async {
    await t.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final cubit = ChatCubit(repo);
    await cubit.load();
    await t.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ChatCubit>.value(value: cubit),
            BlocProvider<WorkspaceCubit>(create: (_) => _Workspace()),
            BlocProvider<ProfileCubit>(create: (_) => _Profile()),
          ],
          child: const ChatScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
    return cubit;
  }

  Future<void> close(WidgetTester t, ChatCubit cubit) async {
    await t.pumpWidget(const SizedBox());
    await cubit.close();
  }

  testWidgets(
    'create channel closes focused sheet safely and shows new channel',
    (t) async {
      final repo = _Repo();
      final cubit = await mount(t, repo);
      await t.tap(find.byKey(const Key('messenger-compose')));
      await t.pumpAndSettle();
      final add = find.text('Добавить канал');
      await t.ensureVisible(add);
      await t.tap(add);
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const Key('channel-name-field')),
        'Новый тест',
      );
      await t.tap(find.byKey(const Key('create-channel-button')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Новый канал'), findsNothing);
      expect(find.text('Новый тест'), findsOneWidget);
      await close(t, cubit);
    },
  );

  testWidgets('cancel focused channel sheet safely', (t) async {
    final repo = _Repo();
    final cubit = await mount(t, repo);
    await t.tap(find.byKey(const Key('messenger-compose')));
    await t.pumpAndSettle();
    final add = find.text('Добавить канал');
    await t.ensureVisible(add);
    await t.tap(add);
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const Key('channel-name-field')),
      'Не сохранять',
    );
    Navigator.of(t.element(find.byKey(const Key('channel-name-field')))).pop();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Не сохранять'), findsNothing);
    await close(t, cubit);
  });

  testWidgets(
    'channel row menu replaces top settings and saves name and members',
    (t) async {
      final repo = _Repo();
      final cubit = await mount(t, repo);
      expect(find.byTooltip('Настройки мессенджера'), findsNothing);
      await t.tap(find.byTooltip('Действия: general'));
      await t.pumpAndSettle();
      for (final label in [
        'Переименовать',
        'Участники',
        'Покинуть канал',
        'Удалить канал',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(t.takeException(), isNull);
      await t.tap(find.text('Переименовать'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'Новое название');
      await t.tap(find.text('Сохранить'));
      await t.pumpAndSettle();
      expect(repo.channel.title, 'Новое название');
      expect(find.text('Новое название'), findsOneWidget);
      await t.tap(find.byTooltip('Действия: Новое название'));
      await t.pumpAndSettle();
      await t.tap(find.text('Участники'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(CheckboxListTile, 'Данияр'));
      await t.tap(find.text('Сохранить'));
      await t.pumpAndSettle();
      expect(repo.selected, ['p']);
      await close(t, cubit);
    },
  );
  testWidgets('personal row has its own menu and clear requires confirmation', (
    t,
  ) async {
    final repo = _Repo();
    final cubit = await mount(t, repo);
    await t.tap(find.byTooltip('Действия: Данияр'));
    await t.pumpAndSettle();
    expect(find.text('Открыть переписку'), findsOneWidget);
    expect(find.text('Переименовать'), findsNothing);
    expect(find.text('Покинуть канал'), findsNothing);
    await t.tap(find.text('Очистить переписку'));
    await t.pumpAndSettle();
    expect(find.textContaining('только у вас'), findsOneWidget);
    await t.tap(find.text('Отмена'));
    await t.pumpAndSettle();
    expect(repo.cleared, isEmpty);
    await t.tap(find.byTooltip('Действия: Данияр'));
    await t.pumpAndSettle();
    await t.tap(find.text('Очистить переписку'));
    await t.pumpAndSettle();
    await t.tap(find.text('Очистить'));
    await t.pumpAndSettle();
    expect(repo.cleared, ['dm:me:p']);
    expect(t.takeException(), isNull);
    await close(t, cubit);
  });
  testWidgets(
    'delete personal chat requires confirmation, preserves it on error and removes it on success',
    (t) async {
      final repo = _Repo();
      final cubit = await mount(t, repo);
      Future<void> openDelete() async {
        await t.tap(find.byTooltip('Действия: Данияр'));
        await t.pumpAndSettle();
        await t.tap(find.text('Удалить чат'));
        await t.pumpAndSettle();
      }

      await openDelete();
      expect(find.textContaining('только у вас'), findsOneWidget);
      await t.tap(find.text('Отмена'));
      await t.pumpAndSettle();
      expect(repo.deletedChats, isEmpty);
      repo.failDelete = true;
      await openDelete();
      await t.tap(find.text('Удалить'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Действия: Данияр'), findsOneWidget);
      expect(repo.deletedChats, isEmpty);
      repo.failDelete = false;
      await openDelete();
      await t.tap(find.text('Удалить'));
      await t.pumpAndSettle();
      expect(repo.deletedChats, ['dm:me:p']);
      expect(find.byTooltip('Действия: Данияр'), findsNothing);
      await cubit.load(silent: true);
      await t.pumpAndSettle();
      expect(find.byTooltip('Действия: Данияр'), findsNothing);
      expect(t.takeException(), isNull);
      await close(t, cubit);
    },
  );

  testWidgets(
    'cancelled delete leaves channel; confirmed delete refreshes list',
    (t) async {
      final repo = _Repo();
      final cubit = await mount(t, repo);
      await t.tap(find.byTooltip('Действия: general'));
      await t.pumpAndSettle();
      await t.tap(find.text('Удалить канал'));
      await t.pumpAndSettle();
      await t.tap(find.text('Отмена'));
      await t.pumpAndSettle();
      expect(repo.deleted, false);
      await t.tap(find.byTooltip('Действия: general'));
      await t.pumpAndSettle();
      await t.tap(find.text('Удалить канал'));
      await t.pumpAndSettle();
      await t.tap(find.text('Удалить'));
      await t.pumpAndSettle();
      expect(repo.deleted, true);
      expect(find.byTooltip('Действия: general'), findsNothing);
      await close(t, cubit);
    },
  );
}

class _Repo
    implements
        ChatRepository,
        ChatActionsRepository,
        ChatThreadActionsRepository {
  ChatConversationModel channel = const ChatConversationModel(
    id: 'c',
    threadId: 'c',
    title: 'general',
    isChannel: true,
  );
  final person = const ChatConversationModel(
    id: 'p',
    threadId: 'dm:me:p',
    title: 'Данияр',
    isChannel: false,
    hasThread: true,
    unreadCount: 2,
  );
  final created = <ChatConversationModel>[];
  bool deleted = false;
  List<String> selected = [];
  final cleared = <String>[];
  final deletedChats = <String>[];
  bool personDeleted = false, failDelete = false;
  @override
  Future<List<ChatConversationModel>> getConversations() async => [
    if (!deleted) channel,
    if (!personDeleted) person,
    ...created,
  ];
  @override
  Future<void> renameChannel(String id, String name) async {
    channel = ChatConversationModel(
      id: channel.id,
      threadId: channel.threadId,
      title: name,
      isChannel: true,
    );
  }

  @override
  Future<List<SpaceMember>> channelMembers(String id) async => [];
  @override
  Future<void> setChannelMembers(String id, List<String> ids) async {
    selected = ids;
  }

  @override
  Future<void> deleteChannel(String id) async {
    deleted = true;
  }

  @override
  Future<void> leaveChannel(String id) async {
    deleted = true;
  }

  @override
  Future<void> deleteConversation(String id) async {
    if (failDelete) throw const ChatException('Не удалось удалить чат.');
    deletedChats.add(id);
    personDeleted = true;
  }

  @override
  Future<void> clearConversation(String id) async {
    cleared.add(id);
  }

  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> toggleFavorite(String id) async {}
  @override
  Future<void> editMessage(String id, String text) async {}
  @override
  Future<void> deleteMessage(String id) async {}
  @override
  Future<List<ChatMessageModel>> getMessages(String id) async => [];
  @override
  Future<ChatConversationModel> createChannel({
    required String name,
    String? parentId,
  }) async {
    final result = ChatConversationModel(
      id: 'new',
      threadId: 'new',
      title: name,
      isChannel: true,
    );
    created.add(result);
    return result;
  }

  @override
  Future<ChatMessageModel> sendMessage({
    required ChatConversationModel conversation,
    required String text,
    ChatMessageKind kind = ChatMessageKind.text,
    String? transcript,
    String? mention,
    int? duration,
  }) async => throw StateError('not used');
}

class _Profile extends Cubit<ProfileState> implements ProfileCubit {
  _Profile() : super(const ProfileInitial());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
