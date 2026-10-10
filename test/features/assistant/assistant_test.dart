import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/assistant/data/models/assistant_message_model.dart';
import 'package:jospar/features/assistant/data/repositories/assistant_repository_impl.dart';
import 'package:jospar/features/assistant/domain/repositories/assistant_repository.dart';
import 'package:jospar/features/assistant/domain/services/assistant_voice.dart';
import 'package:jospar/features/assistant/presentation/cubit/assistant_cubit.dart';
import 'package:jospar/features/assistant/presentation/screens/assistant_screen.dart';
import 'package:jospar/features/workspaces/data/models/create_workspace_request.dart';
import 'package:jospar/features/workspaces/data/models/workspace_model.dart';
import 'package:jospar/features/workspaces/domain/repositories/workspace_repository.dart';

void main() {
  setUp(() async {
    await sl.reset();
    FlutterSecureStorage.setMockInitialValues({
      'selected_workspace_id': 'workspace',
    });
  });
  tearDown(() => sl.reset());
  test('sends conversation to the website API and parses content', () async {
    final adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
      ..httpClientAdapter = adapter;
    final repo = AssistantRepositoryImpl(dio);
    final reply = await repo.chat(
      workspaceId: 'workspace',
      messages: const [
        AssistantMessageModel(role: 'user', content: 'Что на сегодня?'),
      ],
    );
    expect(adapter.request!.path, 'ai/assistant/chat');
    expect(adapter.request!.data, {
      'workspaceId': 'workspace',
      'messages': [
        {'role': 'user', 'content': 'Что на сегодня?'},
      ],
    });
    expect(reply.role, 'assistant');
    expect(reply.content, 'На сегодня две задачи.');
  });
  test(
    'retry preserves one user message rather than duplicating the failed turn',
    () async {
      final repo = _Repository()..fail = true;
      final cubit = _cubit(repo);
      await cubit.initialize();
      await cubit.ask('Мои задачи');
      expect(cubit.state.error, 'Нет сети');
      repo.fail = false;
      await cubit.retry();
      expect(cubit.state.messages.map((e) => e.role), ['user', 'assistant']);
      expect(cubit.state.error, isNull);
      await cubit.close();
    },
  );
  testWidgets(
    'voice launch listens, sends only final words, and speaks the answer',
    (tester) async {
      final voice = _Voice();
      sl.registerSingleton<AssistantVoice>(voice);
      final cubit = _cubit(_Repository());
      addTearDown(cubit.close);
      addTearDown(voice.eventsController.close);
      await cubit.initialize();
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: const MaterialApp(home: AssistantScreen(startVoice: true)),
        ),
      );
      await tester.pumpAndSettle();
      expect(voice.listenCount, 1);
      voice.eventsController.add(
        const VoiceEvent(
          VoiceEventKind.partial,
          VoiceMode.dictation,
          text: 'Мои',
        ),
      );
      await tester.pump();
      expect(cubit.state.messages, isEmpty);
      voice.eventsController.add(
        const VoiceEvent(
          VoiceEventKind.finalResult,
          VoiceMode.dictation,
          text: 'Мои задачи',
        ),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.messages.first.content, 'Мои задачи');
      expect(voice.spoken, 'На сегодня две задачи.');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('microphone error leaves written input available', (
    tester,
  ) async {
    final voice = _Voice()..denied = true;
    sl.registerSingleton<AssistantVoice>(voice);
    final cubit = _cubit(_Repository());
    addTearDown(cubit.close);
    addTearDown(voice.eventsController.close);
    await cubit.initialize();
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: AssistantScreen(startVoice: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Разрешите микрофон'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('assistant-input')), 'Привет');
    await tester.tap(find.byKey(const Key('assistant-send')));
    await tester.pumpAndSettle();
    expect(cubit.state.messages.first.content, 'Привет');
    expect(tester.takeException(), isNull);
  });
}

AssistantCubit _cubit(AssistantRepository repo) => AssistantCubit(
  repo,
  _Workspaces(),
  const WorkspaceSelectionStorage(FlutterSecureStorage()),
);

class _Workspaces implements WorkspaceRepository {
  @override
  Future<List<WorkspaceModel>> getWorkspaces() async => const [
    WorkspaceModel(id: 'workspace', name: 'Команда'),
  ];
  @override
  Future<WorkspaceModel> createWorkspace(CreateWorkspaceRequest request) =>
      throw UnimplementedError();
}

class _Repository implements AssistantRepository {
  bool fail = false;
  @override
  Future<AssistantMessageModel> chat({
    required String workspaceId,
    required List<AssistantMessageModel> messages,
  }) async {
    if (fail) throw const AssistantException('Нет сети');
    return const AssistantMessageModel(
      role: 'assistant',
      content: 'На сегодня две задачи.',
    );
  }
}

class _Voice implements AssistantVoice {
  final eventsController = StreamController<VoiceEvent>.broadcast();
  bool denied = false;
  int listenCount = 0;
  String? spoken;
  bool _listening = false;
  @override
  Stream<VoiceEvent> get events => eventsController.stream;
  @override
  bool get isListening => _listening;
  @override
  Future<void> listen(VoiceMode mode) async {
    listenCount++;
    _listening = !denied;
    eventsController.add(
      VoiceEvent(
        denied ? VoiceEventKind.error : VoiceEventKind.listening,
        mode,
        text: denied ? 'Разрешите микрофон' : '',
      ),
    );
  }

  @override
  Future<void> speak(String text) async {
    spoken = text;
  }

  @override
  Future<void> stop() async {
    _listening = false;
  }

  @override
  Future<void> stopSpeaking() async {}
}

class _Adapter implements HttpClientAdapter {
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({'content': 'На сегодня две задачи.'}),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
