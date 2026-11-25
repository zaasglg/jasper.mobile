import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/features/kanban/data/models/task_translation.dart';
import 'package:jospar/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:jospar/features/kanban/domain/repositories/kanban_repository.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_cubit.dart';
import 'package:jospar/features/kanban/presentation/widgets/kanban_board.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int? failMutation;
  String assistantReply =
      '{"title":"Аударма","description":"Аударылған мәтін"}';
  Map<String, dynamic> task = {
    'id': 'task',
    'title': 'Название',
    'projectId': 'project',
    'status': 'TODO',
    'displayId': 'P-1',
    'progress': 0,
    'priority': 'HIGH',
    'assignees': [
      {
        'userId': 'user',
        'user': {'id': 'user', 'name': 'Имя'},
      },
    ],
    'epics': [
      {'id': 'epic', 'name': 'Эпик'},
    ],
    'detail': {
      'description': 'Описание',
      'comments': [
        {'id': 'comment', 'text': 'Комментарий'},
      ],
      'checklists': [
        {
          'id': 'list',
          'name': 'Проверка',
          'items': [
            {'id': 'item', 'text': 'Пункт', 'done': false},
          ],
        },
      ],
      'files': [],
      'labels': [
        {'id': 'label', 'text': 'Метка'},
      ],
      'custom': {'keep': true},
    },
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    dynamic result;
    var status = 200;
    if (options.method != 'GET' && failMutation != null) {
      status = failMutation!;
      result = {'message': 'Denied'};
    } else if (options.path == 'kanban-columns') {
      result = [
        {'id': 'todo', 'name': 'К работе', 'statusMap': 'TODO', 'order': 0},
      ];
    } else if (options.path == 'project-tasks' && options.method == 'GET') {
      result = [task];
    } else if (options.path == 'project-tasks/task' &&
        options.method == 'GET') {
      result = {'data': task};
    } else if (options.path == 'project-tasks' && options.method == 'POST') {
      result = {
        'data': {
          ...Map<String, dynamic>.from(options.data as Map),
          'id': 'copy',
          'displayId': 'P-2',
        },
      };
    } else if (options.path == 'project-tasks/task' &&
        options.method == 'PATCH') {
      task = {...task, ...Map<String, dynamic>.from(options.data as Map)};
      result = {'data': task};
    } else if (options.path == 'project-tasks/task' &&
        options.method == 'DELETE') {
      result = {};
    } else if (options.path == 'ai/assistant/chat') {
      result = {
        'data': {'content': assistantReply},
      };
    } else {
      status = 404;
      result = {};
    }
    return ResponseBody.fromString(
      jsonEncode(result),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

KanbanRepositoryImpl _repository(_Adapter adapter) => KanbanRepositoryImpl(
  Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
    ..httpClientAdapter = adapter,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'color, image and removed covers preserve existing detail and use web file IDs',
    () async {
      final adapter = _Adapter();
      final repository = _repository(adapter);
      final color = await repository.updateCover('task', {
        'type': 'color',
        'color': '#6366F1',
      });
      expect(color.cover!.color, '#6366F1');
      final image = await repository.updateCover('task', {
        'type': 'image',
        'url': 'data:image/png;base64,AQID',
      });
      final detail = adapter.task['detail'] as Map;
      expect(detail['cover']['fileId'], isNotEmpty);
      expect(detail['cover']['url'], isNull);
      expect(
        (detail['files'] as List).single['dataUrl'],
        'data:image/png;base64,AQID',
      );
      expect(image.cover!.displayUrl, 'data:image/png;base64,AQID');
      await repository.updateCover('task', {
        'type': image.cover!.type,
        'fileId': image.cover!.fileId,
      });
      expect((adapter.task['detail'] as Map)['files'], hasLength(1));
      expect(detail['description'], 'Описание');
      expect(detail['checklists'], hasLength(1));
      expect(detail['comments'], hasLength(1));
      expect(detail['custom'], {'keep': true});
      final cleared = await repository.updateCover('task', null);
      expect(cleared.cover, isNull);
      expect((adapter.task['detail'] as Map)['files'], hasLength(1));
    },
  );

  test(
    'duplicate creates a new task with source data and independent discussion',
    () async {
      final adapter = _Adapter();
      final duplicate = await _repository(adapter).duplicateTask('task');
      expect(duplicate.id, 'copy');
      expect(duplicate.title, 'Название (копия)');
      final body = adapter.requests.last.data as Map;
      expect(body['assigneeIds'], ['user']);
      expect(body['epicIds'], ['epic']);
      expect(body['detail']['description'], 'Описание');
      expect(body['detail']['checklists'], hasLength(1));
      expect(body['detail'].containsKey('comments'), isFalse);
      expect(body.containsKey('timerStartedAt'), isFalse);
      expect(adapter.task['id'], 'task');
    },
  );

  test(
    'translation previews without writing, then applies against fresh detail',
    () async {
      final adapter = _Adapter();
      final repository = _repository(adapter);
      final result = await repository.translateTask(
        'task',
        'workspace',
        'Казахский',
      );
      expect(result.title, 'Аударма');
      expect(adapter.requests.where((r) => r.method == 'PATCH'), isEmpty);
      final chat = adapter.requests.last.data as Map;
      expect(chat['workspaceId'], 'workspace');
      expect(chat['messages'][0]['content'], contains('Казахский'));
      (adapter.task['detail'] as Map)['newField'] = 'added while previewing';
      final translated = await repository.applyTranslation('task', result);
      expect(translated.title, 'Аударма');
      expect(
        (adapter.task['detail'] as Map)['description'],
        'Аударылған мәтін',
      );
      expect(
        (adapter.task['detail'] as Map)['newField'],
        'added while previewing',
      );
      expect((adapter.task['detail'] as Map)['checklists'], hasLength(1));
    },
  );

  test(
    'invalid translations and permission failures report actionable errors',
    () async {
      final adapter = _Adapter()..assistantReply = 'not JSON';
      final repository = _repository(adapter);
      await expectLater(
        repository.translateTask('task', 'workspace', 'Казахский'),
        throwsA(isA<KanbanException>()),
      );
      adapter.failMutation = 403;
      await expectLater(
        repository.deleteTask('task'),
        throwsA(
          isA<KanbanException>().having((e) => e.statusCode, 'status', 403),
        ),
      );
      expect(adapter.requests.last.method, 'DELETE');
      expect(
        TaskTranslation.fromContent(
          '```json\n{"title":"Title","description":"Body"}\n```',
        ).title,
        'Title',
      );
    },
  );

  test(
    'cubit updates copies and covers, previews translation and rolls back failed delete',
    () async {
      final adapter = _Adapter();
      final cubit = KanbanCubit(_repository(adapter));
      await cubit.load('project');
      final original = cubit.state.tasks.single;
      expect(await cubit.duplicateTask(original), isTrue);
      expect(cubit.state.tasks.map((t) => t.id), ['task', 'copy']);
      expect(
        await cubit.updateCover(original, {
          'type': 'color',
          'color': '#6366F1',
        }),
        isTrue,
      );
      expect(cubit.state.tasks.first.cover!.color, '#6366F1');
      final translation = await cubit.translateTask(
        original,
        'workspace',
        'Казахский',
      );
      expect(cubit.state.tasks.first.title, original.title);
      expect(await cubit.applyTranslation(original, translation!), isTrue);
      expect(cubit.state.tasks.first.title, 'Аударма');
      adapter.failMutation = 403;
      await cubit.deleteTask(cubit.state.tasks.first);
      expect(cubit.state.tasks.where((t) => t.id == 'task'), hasLength(1));
      expect(cubit.state.actionErrorMessage, contains('Недостаточно прав'));
      expect(cubit.state.movingTaskIds, isEmpty);
      adapter.failMutation = null;
      await cubit.deleteTask(
        cubit.state.tasks.firstWhere((t) => t.id == 'task'),
      );
      expect(cubit.state.tasks.map((t) => t.id), ['copy']);
      await cubit.close();
    },
  );

  Future<void> pumpBoard(WidgetTester tester, KanbanCubit cubit) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<KanbanCubit>.value(
            value: cubit,
            child: const KanbanBoard(
              project: ProjectModel(
                id: 'project',
                code: 'P',
                name: 'Проект',
                workspaceId: 'workspace',
                start: null,
                end: null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> action(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const ValueKey('task-actions-task')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(name));
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  testWidgets('duplicate and archive menu actions update the board', (
    tester,
  ) async {
    final adapter = _Adapter();
    final cubit = KanbanCubit(_repository(adapter));
    await tester.runAsync(() => cubit.load('project'));
    addTearDown(cubit.close);
    await pumpBoard(tester, cubit);
    await action(tester, 'Дублировать');
    expect(cubit.state.tasks.map((task) => task.id), ['task', 'copy']);
    expect(find.text('Название (копия)'), findsOneWidget);
    await action(tester, 'Архивировать');
    expect(cubit.state.tasks.map((task) => task.id), ['copy']);
    expect((adapter.requests.last.data as Map)['archived'], isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clipboard and native share receive encoded task link', (
    tester,
  ) async {
    final cubit = KanbanCubit(_repository(_Adapter()));
    await tester.runAsync(() => cubit.load('project'));
    addTearDown(cubit.close);
    String? clipboard;
    final shares = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      shares.add(call);
      return 'app';
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(shareChannel, null);
    });
    await pumpBoard(tester, cubit);
    await action(tester, 'Копировать ссылку');
    expect(clipboard, 'https://jospar.me/tasks?project=project&taskId=task');
    await action(tester, 'Поделиться');
    expect(shares, hasLength(1));
    expect((shares.single.arguments as Map)['text'], contains(clipboard!));
  });

  testWidgets('delete requires confirmation, cover save updates board', (
    tester,
  ) async {
    final adapter = _Adapter();
    final cubit = KanbanCubit(_repository(adapter));
    await tester.runAsync(() => cubit.load('project'));
    addTearDown(cubit.close);
    await pumpBoard(tester, cubit);
    await action(tester, 'Удалить задачу');
    expect(find.text('Удалить задачу?'), findsOneWidget);
    expect(adapter.requests.where((r) => r.method == 'DELETE'), isEmpty);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    await action(tester, 'Изменить обложку');
    await tester.tap(find.bySemanticsLabel('Цвет #6366F1'));
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(cubit.state.tasks.single.cover!.color, '#6366F1');
    expect(find.text('Обложка задачи'), findsNothing);
    await action(tester, 'Удалить задачу');
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(cubit.state.tasks, isEmpty);
    expect(adapter.requests.where((r) => r.method == 'DELETE'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'translation displays selected language and restores original without writes',
    (tester) async {
      final adapter = _Adapter();
      final cubit = KanbanCubit(_repository(adapter));
      await tester.runAsync(() => cubit.load('project'));
      addTearDown(cubit.close);
      await pumpBoard(tester, cubit);
      await action(tester, 'Перевести задачу');
      await tester.tap(find.text('Казахский'));
      await tester.pumpAndSettle();
      expect(find.text('Аударма'), findsOneWidget);
      expect(adapter.requests.where((r) => r.method == 'PATCH'), isEmpty);
      expect(cubit.state.tasks.single.title, isNot('Аударма'));
      expect(find.text('Язык перевода'), findsNothing);
      await tester.tap(find.byTooltip('Показать оригинал'));
      await tester.pumpAndSettle();
      expect(find.text('Аударма'), findsNothing);
      expect(cubit.state.translatedTitles, isEmpty);
      expect(adapter.requests.where((r) => r.method == 'PATCH'), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
