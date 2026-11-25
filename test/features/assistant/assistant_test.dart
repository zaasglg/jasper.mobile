import 'package:jospar/features/assistant/presentation/widgets/assistant_web_layout.dart';
import 'package:jospar/features/assistant/domain/entities/assistant_request.dart';
import 'package:jospar/features/assistant/data/services/assistant_attachment_picker.dart';
import 'package:jospar/features/assistant/domain/entities/assistant_attachment.dart';
import 'package:jospar/features/assistant/data/models/assistant_message_dto.dart';
import 'package:jospar/features/assistant/data/services/assistant_actions.dart';
import 'package:jospar/features/assistant/presentation/widgets/assistant_action_cards.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'package:jospar/features/assistant/domain/entities/assistant_message_model.dart';
import 'package:jospar/features/assistant/data/repositories/assistant_repository_impl.dart';
import 'package:jospar/features/assistant/domain/repositories/assistant_repository.dart';
import 'package:jospar/features/assistant/domain/services/assistant_voice.dart';
import 'package:jospar/features/assistant/presentation/cubit/assistant_cubit.dart';
import 'package:jospar/features/assistant/presentation/screens/assistant_screen.dart';
import 'package:jospar/features/workspaces/domain/entities/create_workspace_request.dart';
import 'package:jospar/features/workspaces/domain/entities/workspace_model.dart';
import 'package:jospar/features/workspaces/domain/repositories/workspace_repository.dart';

void main() {
  testWidgets('compact composer fits large text and keeps actions available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final input = TextEditingController(text: 'Мой вопрос');
    final focus = FocusNode();
    addTearDown(input.dispose);
    addTearDown(focus.dispose);
    var sent = 0;
    var plans = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AssistantWebComposer(
              input: input,
              focus: focus,
              enabled: true,
              sending: false,
              listening: false,
              picking: false,
              attachments: const [],
              onSend: () => sent++,
              onVoice: () {},
              onAttach: () {},
              onRemove: (_) {},
              onDayPlan: () => plans++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-ai-day-plan')));
    await tester.tap(find.byKey(const Key('assistant-send')));
    expect(plans, 1);
    expect(sent, 1);
    expect(tester.takeException(), isNull);
  });

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await sl.reset();
    _Actions.created = 0;
    FlutterSecureStorage.setMockInitialValues({
      'selected_workspace_id': 'workspace',
    });
  });
  tearDown(() => sl.reset());
  test(
    'file-only retry keeps its file and does not duplicate a user turn',
    () async {
      final repo = _Repository()..fail = true;
      final cubit = AssistantCubit(
        repo,
        _Workspaces(),
        const WorkspaceSelectionStorage(FlutterSecureStorage()),
      );
      addTearDown(cubit.close);
      await cubit.initialize();
      final file = AssistantAttachmentPicker.fromBytes(
        'plan.txt',
        Uint8List.fromList(utf8.encode('Plan')),
      );
      await cubit.ask('', attachments: [file]);
      expect(cubit.state.messages.single.attachments, [file]);
      repo.fail = false;
      await cubit.retry();
      expect(repo.attachmentRequests, [
        [file],
        [file],
      ]);
      expect(cubit.state.messages.where((m) => m.role == 'user').length, 1);
    },
  );
  test('unsupported file extraction avoids a second model request', () async {
    final repo = _Repository();
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            h.resolve(
              Response(
                requestOptions: o,
                data: {
                  'isTaskDetected': false,
                  'attachmentMessage': 'Нет текстового слоя',
                  'attachments': [
                    {
                      'name': 'scan.pdf',
                      'mimeType': 'application/pdf',
                      'size': 4,
                      'status': 'unsupported',
                      'reason': 'Нет текстового слоя',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
    const selection = WorkspaceSelectionStorage(FlutterSecureStorage());
    final cubit = AssistantCubit(
      repo,
      _Workspaces(),
      selection,
      actions: AssistantActions(dio, selection),
    );
    addTearDown(cubit.close);
    await cubit.initialize();
    await cubit.ask(
      '',
      attachments: const [
        AssistantAttachment(
          name: 'scan.pdf',
          mimeType: 'application/pdf',
          size: 4,
          dataUrl: 'data:application/pdf;base64,dGVzdA==',
        ),
      ],
    );
    expect(repo.attachmentRequests, isEmpty);
    expect(cubit.state.messages.last.content, 'Нет текстового слоя');
    expect(cubit.state.messages.last.attachments.single.status, 'unsupported');
  });
  test('tool results and project context survive API parsing', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.data['currentProjectId'], 'project');
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'content': 'Готово',
                'toolCalls': [
                  {
                    'name': 'open_task',
                    'result': {
                      'action': {
                        'type': 'open_task',
                        'taskId': 'task',
                        'workspaceId': 'workspace',
                      },
                    },
                  },
                ],
              },
            ),
          );
        },
      ),
    );
    final reply = await AssistantRepositoryImpl(dio).chat(
      workspaceId: 'workspace',
      messages: const [],
      currentProjectId: 'project',
    );
    expect(reply.tools.single.name, 'open_task');
    expect(
      AssistantMessageDto.fromJson(
        AssistantMessageDto.fromEntity(reply).toJson(),
      ).toEntity(),
      reply,
    );
  });
  testWidgets('draft cancel never creates a task and survives rebuilding', (
    tester,
  ) async {
    final repo = _Repository();
    final cubit = AssistantCubit(
      repo,
      _Workspaces(),
      const WorkspaceSelectionStorage(FlutterSecureStorage()),
      actions: _Actions(),
    );
    addTearDown(cubit.close);
    await cubit.initialize();
    await cubit.ask('Создай задачу');
    expect(repo.imageRequests, isEmpty);
    final message = cubit.state.messages.last;
    expect(message.draft!.title, 'Проверить');
    Widget page() => MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(body: AssistantActionCards(message: message, index: 1)),
      ),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text('Добавить задачу'), findsOneWidget);
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Создание отменено'), findsOneWidget);
    expect((_Actions.created), 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text('Создание отменено'), findsOneWidget);
  });
  testWidgets('historical drafts cannot create tasks again', (tester) async {
    final cubit = AssistantCubit(
      _Repository(),
      _Workspaces(),
      const WorkspaceSelectionStorage(FlutterSecureStorage()),
      actions: _Actions(),
    );
    addTearDown(cubit.close);
    await cubit.initialize();
    await cubit.ask('Создай задачу');
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: AssistantActionCards(
              message: cubit.state.messages.last,
              index: 1,
              readOnly: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Добавить задачу'), findsNothing);
    expect(find.textContaining('Черновик из истории'), findsOneWidget);
    expect(_Actions.created, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('action summary separates confirmed updates and failures', (
    tester,
  ) async {
    final reply = AssistantMessageDto.fromJson({
      'role': 'assistant',
      'content': 'Проверено',
      'toolCalls': [
        {
          'name': 'update_task',
          'result': {
            'updated': {
              'id': 't',
              'title': 'Отчёт',
              'workspaceId': 'workspace',
            },
          },
        },
        {'name': 'update_task', 'result': {}},
        {
          'name': 'search_messages',
          'result': {'error': 'Недоступно'},
        },
      ],
    }).toEntity();
    final cubit = _cubit(_Repository()..reply = reply);
    addTearDown(cubit.close);
    await cubit.initialize();
    await cubit.ask('Проверь');
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: SingleChildScrollView(
              child: AssistantActionCards(
                message: cubit.state.messages.last,
                index: 1,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Действия · 1 выполнено · есть ошибки'));
    await tester.pumpAndSettle();
    expect(find.text('Изменения сохранены: Отчёт'), findsOneWidget);
    expect(find.text('Сервер не подтвердил сохранение'), findsOneWidget);
    expect(find.text('Не удалось выполнить'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('confirm creates a draft only once', (tester) async {
    final cubit = AssistantCubit(
      _Repository(),
      _Workspaces(),
      const WorkspaceSelectionStorage(FlutterSecureStorage()),
      actions: _Actions(),
    )..currentProjectId = 'project';
    addTearDown(cubit.close);
    await cubit.initialize();
    await cubit.ask('Создай задачу');
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: AssistantActionCards(
              message: cubit.state.messages.last,
              index: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить задачу'));
    await tester.pumpAndSettle();
    expect(find.text('Задача создана'), findsOneWidget);
    expect(_Actions.created, 1);
    expect(find.text('Добавить задачу'), findsNothing);
  });
  testWidgets('edit tools show changes and apply only after confirmation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repository()
      ..reply = AssistantMessageDto(
        role: 'assistant',
        content: 'Подготовлено',
        tools: [
          {
            'name': 'prepare_task_edit',
            'result': {
              'draft': {
                'type': 'task_edit_draft',
                'taskId': 'task',
                'projectId': 'project',
                'workspaceId': 'workspace',
                'title': 'Название',
                'patch': {'title': 'Новое'},
                'previous': {'title': 'Старое'},
              },
            },
          },
          {
            'name': 'search_messages',
            'result': {
              'results': [
                {
                  'attachment': {
                    'messageId': 'm',
                    'name': 'Смета.pdf',
                    'size': '123 КБ',
                  },
                },
              ],
            },
          },
        ],
      ).toEntity();
    final actions = _Actions()..detect = false;
    final cubit = AssistantCubit(
      repo,
      _Workspaces(),
      const WorkspaceSelectionStorage(FlutterSecureStorage()),
      actions: actions,
    );
    addTearDown(cubit.close);
    await cubit.initialize();
    await cubit.ask('Подготовь изменения');
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: SingleChildScrollView(
              child: AssistantActionCards(
                message: cubit.state.messages.last,
                index: 1,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Смета.pdf'), findsOneWidget);
    expect(find.text('Название: Старое → Новое'), findsOneWidget);
    expect(actions.applied, 0);
    await tester.ensureVisible(find.text('Применить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    expect(actions.applied, 1);
    expect(find.text('Изменения сохранены'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
  test(
    'images are sent on the current turn and excluded from API history',
    () async {
      final adapter = _Adapter();
      final repo = AssistantRepositoryImpl(Dio()..httpClientAdapter = adapter);
      const image = 'data:image/png;base64,aGVsbG8=';
      const message = AssistantMessageModel(
        role: 'user',
        content: 'Что на изображении?',
        images: [image],
      );
      expect(
        AssistantMessageDto.fromJson(
          AssistantMessageDto.fromEntity(message).toJson(),
        ).toEntity(),
        message,
      );
      await repo.chat(
        workspaceId: 'workspace',
        messages: [message],
        images: [image],
      );
      expect(adapter.request!.data['images'], [image]);
      expect(adapter.request!.data['messages'], [
        {'role': 'user', 'content': 'Что на изображении?'},
      ]);
      await repo.chat(
        workspaceId: 'workspace',
        messages: [
          message,
          const AssistantMessageModel(role: 'user', content: 'Продолжи'),
        ],
      );
      expect((adapter.request!.data as Map).containsKey('images'), isFalse);
    },
  );
  test('image-only requests preserve their attachment on retry', () async {
    final repo = _Repository()..fail = true;
    final cubit = _cubit(repo);
    addTearDown(cubit.close);
    await cubit.initialize();
    const image = 'data:image/png;base64,aGVsbG8=';
    await cubit.ask('', images: [image]);
    expect(cubit.state.messages.single.images, [image]);
    repo.fail = false;
    await cubit.retry();
    expect(cubit.state.messages.where((m) => m.role == 'user').length, 1);
    expect(cubit.state.messages.first.images, [image]);
    expect(repo.imageRequests, [
      [image],
      [image],
    ]);
  });
  testWidgets(
    'widget opens keyboard without activating microphone or sending',
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
          child: const MaterialApp(home: AssistantScreen(startKeyboard: true)),
        ),
      );
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(
        find.byKey(const Key('assistant-input')),
      );
      expect(input.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(voice.listenCount, 0);
      expect(cubit.state.messages, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('draft follows conversation selection through history UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final voice = _Voice();
    sl.registerSingleton<AssistantVoice>(voice);
    final cubit = _cubit(_Repository());
    addTearDown(cubit.close);
    addTearDown(voice.eventsController.close);
    await cubit.initialize();
    cubit.updateDraft('Первый черновик');
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          theme: ThemeData.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const AssistantScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    TextField field() =>
        tester.widget<TextField>(find.byKey(const Key('assistant-input')));
    expect(field().controller!.text, 'Первый черновик');
    await tester.tap(find.byTooltip('Новый диалог'));
    await tester.pumpAndSettle();
    expect(field().controller!.text, isEmpty);
    await tester.enterText(
      find.byKey(const Key('assistant-input')),
      'Второй черновик',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('История диалогов'));
    await tester.pumpAndSettle();
    final drawer = tester.widget<Drawer>(find.byType(Drawer));
    expect(drawer.backgroundColor, Colors.white);
    expect(drawer.surfaceTintColor, Colors.transparent);
    await tester.tap(find.text('Первый черновик'));
    await tester.pumpAndSettle();
    expect(field().controller!.text, 'Первый черновик');
    expect(voice.listenCount, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('stop button cancels waiting and discards the late answer', (
    tester,
  ) async {
    final voice = _Voice();
    sl.registerSingleton<AssistantVoice>(voice);
    final reply = Completer<AssistantMessageModel>();
    final repository = _Repository()..waiting = reply;
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    addTearDown(voice.eventsController.close);
    await cubit.initialize();
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: AssistantScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final pending = cubit.ask('Долгий запрос');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Остановить'));
    await tester.pumpAndSettle();
    expect(repository.lastRequest!.isCancelled, isTrue);
    expect(find.textContaining('Ответ остановлен.'), findsOneWidget);
    reply.complete(
      const AssistantMessageModel(role: 'assistant', content: 'Поздний ответ'),
    );
    await pending;
    await tester.pumpAndSettle();
    expect(find.text('Поздний ответ'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('website starter fills the composer without sending a request', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final voice = _Voice();
    sl.registerSingleton<AssistantVoice>(voice);
    final cubit = _cubit(_Repository());
    addTearDown(cubit.close);
    addTearDown(voice.eventsController.close);
    await cubit.initialize();
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: AssistantScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Что поручим агенту?'), findsOneWidget);
    await tester.ensureVisible(find.text('Найти информацию'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Найти информацию'));
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(
      find.byKey(const Key('assistant-input')),
    );
    expect(
      input.controller!.text,
      'Помоги найти информацию в рабочем пространстве: ',
    );
    expect(cubit.state.messages, isEmpty);
    expect(tester.takeException(), isNull);
  });
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
    await tester.pump();
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
  Future<List<WorkspaceModel>> getArchivedWorkspaces() async => [];

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
  AssistantMessageModel? reply;
  Completer<AssistantMessageModel>? waiting;
  AssistantRequest? lastRequest;
  final imageRequests = <List<String>>[];
  final attachmentRequests = <List<AssistantAttachment>>[];
  @override
  Future<AssistantMessageModel> chat({
    required String workspaceId,
    required List<AssistantMessageModel> messages,
    List<String> images = const [],
    List<AssistantAttachment> attachments = const [],
    String? currentProjectId,
    AssistantRequest? request,
  }) async {
    lastRequest = request;
    imageRequests.add(List.from(images));
    attachmentRequests.add(List.from(attachments));
    if (fail) throw const AssistantException('Нет сети');
    if (waiting != null) return waiting!.future;
    return reply ??
        const AssistantMessageModel(
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

class _Actions extends AssistantActions {
  _Actions()
    : super(Dio(), const WorkspaceSelectionStorage(FlutterSecureStorage()));
  static int created = 0;
  bool detect = true;
  int applied = 0;
  @override
  Future<void> apply(String workspaceId, Map<String, dynamic> draft) async {
    applied++;
  }

  @override
  Future<Map<String, dynamic>?> extract(
    String workspaceId,
    String text,
    List<String> images,
    String? projectId, {
    AssistantRequest? request,
  }) async => detect ? {'title': 'Проверить'} : null;
  @override
  Future<List<Map<String, dynamic>>> projects(String workspaceId) async => [
    {'id': 'project', 'name': 'Проект', 'workspaceId': 'workspace'},
  ];
  @override
  Future<void> create(
    String workspaceId,
    String projectId,
    Map<String, dynamic> draft,
  ) async {
    created++;
  }
}
