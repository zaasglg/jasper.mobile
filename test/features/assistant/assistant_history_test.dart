import 'package:jospar/features/assistant/domain/repositories/assistant_history_repository.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/assistant/data/repositories/assistant_history_repository_impl.dart';
import 'package:jospar/features/assistant/data/repositories/assistant_repository_impl.dart';
import 'package:jospar/features/assistant/domain/entities/assistant_attachment.dart';
import 'package:jospar/features/assistant/domain/entities/assistant_conversation.dart';
import 'package:jospar/features/assistant/domain/entities/assistant_message_model.dart';
import 'package:jospar/features/assistant/domain/entities/assistant_request.dart';
import 'package:jospar/features/assistant/domain/entities/assistant_draft.dart';
import 'package:jospar/features/assistant/domain/repositories/assistant_repository.dart';
import 'package:jospar/features/assistant/presentation/cubit/assistant_cubit.dart';
import 'package:jospar/features/assistant/presentation/cubit/assistant_state.dart';
import 'package:jospar/features/workspaces/domain/entities/create_workspace_request.dart';
import 'package:jospar/features/workspaces/domain/entities/workspace_model.dart';
import 'package:jospar/features/workspaces/domain/repositories/workspace_repository.dart';

class _Workspaces implements WorkspaceRepository {
  @override
  Future<List<WorkspaceModel>> getWorkspaces() async => [
    const WorkspaceModel(id: 'w', name: 'Команда'),
  ];
  @override
  Future<List<WorkspaceModel>> getArchivedWorkspaces() async => [];
  @override
  Future<WorkspaceModel> createWorkspace(CreateWorkspaceRequest request) =>
      throw UnimplementedError();
}

class _Chat implements AssistantRepository {
  Completer<AssistantMessageModel>? pending;
  final requests = <AssistantRequest?>[];
  final sentMessages = <List<AssistantMessageModel>>[];
  @override
  Future<AssistantMessageModel> chat({
    required String workspaceId,
    required List<AssistantMessageModel> messages,
    List<String> images = const [],
    List<AssistantAttachment> attachments = const [],
    String? currentProjectId,
    AssistantRequest? request,
  }) {
    requests.add(request);
    sentMessages.add(messages);
    final wait = pending;
    pending = null;
    return wait?.future ??
        Future.value(
          const AssistantMessageModel(role: 'assistant', content: 'Готово'),
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuthTokenStorage tokens;
  const storage = FlutterSecureStorage();
  String token(String id) =>
      'x.${base64Url.encode(utf8.encode(jsonEncode({'sub': id})))}.x';
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'selected_workspace_id': 'w'});
    tokens = AuthTokenStorage(storage);
    await tokens.save(token('alice'));
  });
  AssistantHistoryRepositoryImpl history() =>
      AssistantHistoryRepositoryImpl(tokens, storage);
  AssistantCubit cubit(_Chat chat) => AssistantCubit(
    chat,
    _Workspaces(),
    const WorkspaceSelectionStorage(storage),
    history: history(),
  );

  test(
    'history roundtrip retains action status and strips media, scoped by account and workspace',
    () async {
      final repository = history();
      final scope = (await repository.scope('w'))!;
      await repository.save(scope, [
        AssistantConversation(
          id: 'c',
          updatedAt: DateTime(2026),
          draft: 'Черновик',
          messages: const [
            AssistantMessageModel(
              role: 'user',
              content: 'Запрос',
              images: ['data:image/png;base64,AQID'],
              attachments: [
                AssistantAttachment(
                  name: 'plan.txt',
                  mimeType: 'text/plain',
                  size: 3,
                  dataUrl: 'data:text/plain;base64,AQID',
                ),
              ],
            ),
            AssistantMessageModel(
              role: 'assistant',
              content: 'Создано',
              actionStates: {'create': 'created'},
              draft: AssistantDraft(title: 'Задача', workspaceId: 'w'),
            ),
          ],
        ),
      ]);
      final restored = (await history().load(scope)).single;
      expect(restored.draft, 'Черновик');
      expect(restored.messages.first.images, isEmpty);
      expect(restored.messages.first.attachments.single.dataUrl, isNull);
      expect(restored.messages.last.actionStates, {'create': 'created'});
      expect(restored.messages.last.draft!.title, 'Задача');
      expect(
        await repository.load((await repository.scope('other'))!),
        isEmpty,
      );
      await tokens.save(token('bob'));
      expect(await repository.load((await repository.scope('w'))!), isEmpty);
    },
  );

  test(
    'drafts and conversations survive restart, switching and deletion',
    () async {
      final first = cubit(_Chat());
      await first.initialize();
      first.updateDraft('Несохранённый запрос');
      await first.close();
      final second = cubit(_Chat());
      await second.initialize();
      expect(second.state.draft, 'Несохранённый запрос');
      await second.ask('Первый вопрос');
      final old = second.state.conversationId;
      await second.newConversation();
      expect(second.state.messages, isEmpty);
      second.updateDraft('Второй черновик');
      final newer = second.state.conversationId;
      await second.openConversation(old);
      expect(second.state.messages.last.content, 'Готово');
      expect(second.state.restoredMessageCount, 2);
      await second.openConversation(newer);
      expect(second.state.draft, 'Второй черновик');
      await second.deleteConversation(old);
      await second.close();
      final third = cubit(_Chat());
      await third.initialize();
      expect(third.state.conversationId, newer);
      expect(third.state.draft, 'Второй черновик');
      expect(third.state.conversations.any((c) => c.id == old), isFalse);
      await third.newConversation();
      await third.close();
      final fourth = cubit(_Chat());
      await fourth.initialize();
      expect(fourth.state.messages, isEmpty);
      expect(fourth.state.draft, isEmpty);
      await fourth.close();
    },
  );

  test(
    'stop cancels request and late replies cannot overwrite a newer conversation',
    () async {
      final reply = Completer<AssistantMessageModel>();
      final chat = _Chat()..pending = reply;
      final assistant = cubit(chat);
      await assistant.initialize();
      final pending = assistant.ask('Медленный запрос');
      await Future<void>.delayed(Duration.zero);
      expect(assistant.state.status, AssistantStatus.sending);
      assistant.stop();
      expect(chat.requests.single!.isCancelled, isTrue);
      expect(assistant.state.messages.last.cancelled, isTrue);
      expect(assistant.state.stopped, isTrue);
      await assistant.newConversation();
      await assistant.ask('Новый запрос');
      reply.complete(
        const AssistantMessageModel(
          role: 'assistant',
          content: 'Устаревший ответ',
        ),
      );
      await pending;
      expect(assistant.state.messages.map((m) => m.content), [
        'Новый запрос',
        'Готово',
      ]);
      expect(assistant.state.status, AssistantStatus.ready);
      await assistant.close();
    },
  );

  test('stopped requests are excluded from subsequent model context', () async {
    final reply = Completer<AssistantMessageModel>();
    final chat = _Chat()..pending = reply;
    final assistant = cubit(chat);
    await assistant.initialize();
    final pending = assistant.ask('Старое поручение');
    await Future<void>.delayed(Duration.zero);
    assistant.stop();
    await assistant.ask('Новое поручение');
    expect(chat.sentMessages.last.map((m) => m.content), ['Новое поручение']);
    reply.complete(
      const AssistantMessageModel(role: 'assistant', content: 'Поздно'),
    );
    await pending;
    await assistant.close();
  });

  test(
    'history failures remain visible without preventing chat and can be retried',
    () async {
      final store = _FailingHistory();
      final assistant = AssistantCubit(
        _Chat(),
        _Workspaces(),
        const WorkspaceSelectionStorage(storage),
        history: store,
      );
      await assistant.initialize();
      await assistant.ask('Привет');
      expect(assistant.state.status, AssistantStatus.ready);
      expect(assistant.state.historyError, isNotNull);
      store.fail = false;
      await assistant.saveHistory();
      expect(assistant.state.historyError, isNull);
      await assistant.close();
    },
  );

  test('HTTP cancellation aborts the pending chat transport', () async {
    final started = Completer<void>();
    final dio = Dio()..httpClientAdapter = _WaitingAdapter(started);
    addTearDown(dio.close);
    final request = AssistantRequest();
    final response = AssistantRepositoryImpl(dio).chat(
      workspaceId: 'w',
      messages: const [AssistantMessageModel(role: 'user', content: 'Вопрос')],
      request: request,
    );
    await started.future;
    final check = expectLater(response, throwsA(isA<AssistantException>()));
    request.cancel();
    await check;
  });
}

class _WaitingAdapter implements HttpClientAdapter {
  _WaitingAdapter(this.started);
  final Completer<void> started;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    started.complete();
    await cancelFuture;
    throw DioException.requestCancelled(
      requestOptions: options,
      reason: 'Stopped',
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FailingHistory implements AssistantHistoryRepository {
  bool fail = true;
  @override
  Future<String?> scope(String workspaceId) async => 'scope';
  @override
  Future<List<AssistantConversation>> load(String scope) async => [];
  @override
  Future<void> save(
    String scope,
    List<AssistantConversation> conversations,
  ) async {
    if (fail) throw StateError('Unavailable');
  }
}
