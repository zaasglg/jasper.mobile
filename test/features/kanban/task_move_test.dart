import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/auth/auth_session.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:jospar/features/kanban/data/repositories/task_move_repository_impl.dart';
import 'package:jospar/features/kanban/domain/entities/kanban_board_cache.dart';
import 'package:jospar/features/kanban/domain/entities/kanban_board_data.dart';
import 'package:jospar/features/kanban/domain/entities/task_move_target.dart';
import 'package:jospar/features/kanban/domain/repositories/task_move_repository.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_cubit.dart';
import 'package:jospar/features/kanban/presentation/widgets/kanban_board.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';
import 'package:jospar/features/tasks/data/services/task_changes.dart';

const project = ProjectModel(
  id: 'p',
  code: 'PR',
  name: 'Исходный проект',
  workspaceId: 'w',
  start: null,
  end: null,
);
const destination = TaskMoveTarget(
  workspaceId: 'w2',
  projectId: 'p2',
  status: 'REVIEW',
);
const _preview = bool.fromEnvironment('CAPTURE_MOVE_PREVIEWS');
final _previewKey = GlobalKey();

class _Api implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final projectGates = <String, Completer<void>>{};
  Completer<void>? moveGate;
  int moveStatus = 200;
  bool failProjects = false;
  final emptyColumns = <String>{};
  String taskProject = 'p', taskStatus = 'TODO';
  List<RequestOptions> get moves =>
      requests.where((r) => r.method == 'POST').toList();
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    final scope = request.headers['X-Workspace-Id'] ?? 'w';
    switch (request.path) {
      case 'workspaces':
        return _json([
          {'id': 'w', 'name': 'Команда'},
          {'id': 'w2', 'name': 'Личное пространство'},
          {'id': 'w3', 'name': 'Другое пространство'},
          {'id': 'old', 'name': 'Архив', 'archivedAt': '2026-01-01'},
        ]);
      case 'projects':
        await projectGates[scope]?.future;
        if (failProjects) return _json({}, 403);
        if (scope == 'w') {
          return _json({
            'data': [
              project.toJson()
                ..['children'] = [
                  {'id': 'child', 'name': 'Подпроект', 'code': 'CH'},
                ],
              {'id': 'foreign', 'workspaceId': 'w2'},
              {'id': 'archived', 'workspaceId': 'w', 'archived': true},
            ],
          });
        }
        return _json([
          {
            'id': scope == 'w2' ? 'p2' : 'p3',
            'workspaceId': scope,
            'name': scope == 'w2' ? 'Принимающий проект' : 'Третий проект',
          },
        ]);
      case 'kanban-columns':
        final id = request.queryParameters['projectId'];
        if (emptyColumns.contains(id)) return _json([]);
        return _json([
          {
            'id': 'todo-$id',
            'projectId': id,
            'name': 'К работе',
            'statusMap': 'TODO',
            'order': 0,
          },
          {
            'id': 'review-$id',
            'projectId': id,
            'name': 'На проверке',
            'statusMap': 'REVIEW',
            'order': 1,
          },
          {
            'id': 'old-$id',
            'projectId': id,
            'name': 'Скрытая',
            'statusMap': 'OLD',
            'archivedAt': '2026-01-01',
          },
        ]);
      case 'project-tasks':
        final id = request.queryParameters['projectId'];
        return _json([
          if (id == taskProject)
            {
              'id': 'task',
              'projectId': taskProject,
              'status': taskStatus,
              'title': 'Подготовить материалы для встречи',
              'progress': 40,
            },
          {
            'id': 'other-$id',
            'projectId': id,
            'status': 'TODO',
            'title': 'Другая задача',
          },
        ]);
      case 'project-tasks/task/move':
        await moveGate?.future;
        if (moveStatus != 200) return _json({}, moveStatus);
        final data = request.data as Map;
        taskProject = data['projectId'] as String;
        taskStatus = data['status'] as String;
        return _json({});
      default:
        throw StateError(
          'Unexpected request ${request.method} ${request.path}',
        );
    }
  }

  ResponseBody _json(Object data, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(data),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
  @override
  void close({bool force = false}) {}
}

({KanbanCubit cubit, TaskMoveRepositoryImpl repository}) _setup(
  _Api api, {
  KanbanBoardCache? cache,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
    ..httpClientAdapter = api;
  final repository = TaskMoveRepositoryImpl(dio);
  return (
    cubit: KanbanCubit(
      KanbanRepositoryImpl(dio),
      cache: cache,
      taskMoveRepository: repository,
    ),
    repository: repository,
  );
}

Future<void> showBoard(
  WidgetTester tester,
  KanbanCubit cubit, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _previewKey,
      child: MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const KanbanBoard(project: project),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openMove(WidgetTester tester, {bool hold = false}) async {
  if (hold) {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('task'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.text('Переместить')));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
  } else {
    await tester.tap(find.byKey(const ValueKey('task-actions-task')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переместить'));
  }
  await tester.pumpAndSettle();
}

Future<void> select(WidgetTester tester, String key, String text) async {
  final field = find.byKey(Key(key));
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (!_preview) return;
    final font = ByteData.sublistView(
      await File('.codex/visual/project-board/Manrope.ttf').readAsBytes(),
    );
    for (final family in [
      'Manrope',
      for (final weight in [400, 500, 600, 700, 800]) 'Manrope_$weight',
    ]) {
      await (FontLoader(family)..addFont(Future.value(font))).load();
    }
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  tearDown(() async {
    await sl.reset();
  });

  test(
    'destination lists use explicit scopes, flatten children and exclude archives',
    () async {
      final api = _Api();
      final result = _setup(api);
      addTearDown(result.cubit.close);
      expect((await result.repository.workspaces()).map((w) => w.id), [
        'w',
        'w2',
        'w3',
      ]);
      expect((await result.repository.projects('w')).map((p) => p.id), [
        'p',
        'child',
      ]);
      expect((await result.repository.columns('w2', 'p2')).map((c) => c.id), [
        'todo-p2',
        'review-p2',
      ]);
      expect(api.requests.last.headers['X-Workspace-Id'], 'w2');
      expect(api.requests.where((r) => r.path == 'project-tasks'), isEmpty);
    },
  );

  test(
    'cross-workspace transfer locks once, keeps source until success and invalidates destination cache',
    () async {
      final api = _Api()..moveGate = Completer<void>();
      final cache = KanbanBoardCache()
        ..write('p2', const KanbanBoardData(columns: [], tasks: []));
      final result = _setup(api, cache: cache);
      addTearDown(result.cubit.close);
      await result.cubit.load('p');
      final task = result.cubit.state.tasks.first;
      final revision = taskChanges.value;
      final moving = result.cubit.transferTask(task, destination);
      expect(result.cubit.state.movingTaskIds, {'task'});
      expect(result.cubit.state.tasks.first.progress, 40);
      expect(await result.cubit.transferTask(task, destination), isFalse);
      await Future<void>.delayed(Duration.zero);
      api.moveGate!.complete();
      expect(await moving, isTrue);
      expect(result.cubit.state.tasks.map((t) => t.id), ['other-p']);
      expect(cache.read('p2'), isNull);
      expect(taskChanges.value, revision + 1);
      expect(api.moves.single.headers['X-Workspace-Id'], 'w2');
      expect(api.moves.single.data, {'projectId': 'p2', 'status': 'REVIEW'});
    },
  );

  test('rejected transfer leaves source unchanged and can retry', () async {
    final api = _Api()..moveStatus = 403;
    final result = _setup(api);
    addTearDown(result.cubit.close);
    await result.cubit.load('p');
    final task = result.cubit.state.tasks.first;
    expect(await result.cubit.transferTask(task, destination), isFalse);
    expect(result.cubit.state.tasks.first, task);
    expect(result.cubit.state.movingTaskIds, isEmpty);
    expect(
      result.cubit.state.actionErrorMessage,
      contains('Недостаточно прав'),
    );
    api.moveStatus = 200;
    expect(
      await result.cubit.transferTask(task, destination.copyWith(position: 0)),
      isTrue,
    );
    expect(api.moves.last.data, {
      'projectId': 'p2',
      'status': 'REVIEW',
      'position': 0,
    });
  });

  test(
    'late transfer refreshes the active board without restoring the old project',
    () async {
      final api = _Api()..moveGate = Completer<void>();
      final result = _setup(api);
      addTearDown(result.cubit.close);
      await result.cubit.load('p');
      final moving = result.cubit.transferTask(
        result.cubit.state.tasks.first,
        destination,
      );
      await result.cubit.load('p2');
      final refreshed = result.cubit.stream.firstWhere(
        (state) =>
            state.projectId == 'p2' &&
            state.tasks.any((task) => task.id == 'task'),
      );
      api.moveGate!.complete();
      expect(await moving, isTrue);
      await refreshed;
      expect(result.cubit.state.projectId, 'p2');
      expect(
        result.cubit.state.tasks.where((t) => t.id == 'task').single.projectId,
        'p2',
      );
    },
  );

  test('late transfer cannot invalidate data in a new account', () async {
    final api = _Api()..moveGate = Completer<void>();
    final result = _setup(api);
    addTearDown(result.cubit.close);
    await result.cubit.load('p');
    final moving = result.cubit.transferTask(
      result.cubit.state.tasks.first,
      destination,
    );
    final revision = taskChanges.value;
    authSession.markAuthenticated();
    api.moveGate!.complete();
    expect(await moving, isFalse);
    expect(result.cubit.state.tasks, isEmpty);
    expect(taskChanges.value, revision);
  });

  for (final hold in [false, true]) {
    testWidgets(
      'moves through ${hold ? 'hold target' : 'card menu'} only after confirmation',
      (tester) async {
        final api = _Api();
        final result = _setup(api);
        addTearDown(result.cubit.close);
        sl.registerSingleton<TaskMoveRepository>(result.repository);
        await tester.runAsync(() => result.cubit.load('p'));
        await showBoard(tester, result.cubit);
        await openMove(tester, hold: hold);
        expect(find.textContaining('Инбокс'), findsNothing);
        if (!hold) {
          await select(tester, 'move-workspace-field', 'Личное пространство');
          await select(tester, 'move-project-field', 'Принимающий проект');
        } else {
          await select(tester, 'move-project-field', 'Подпроект');
        }
        final columnId = hold ? 'review-child' : 'review-p2';
        await tester.ensureVisible(find.byKey(ValueKey('move-to-$columnId')));
        await tester.tap(find.byKey(ValueKey('move-to-$columnId')));
        await tester.pumpAndSettle();
        expect(api.moves, isEmpty);
        expect(result.cubit.state.projectId, 'p');
        final confirm = find.byKey(const Key('confirm-task-move'));
        expect(tester.getRect(confirm).bottom, lessThan(844));
        if (_preview && !hold) {
          await tester.runAsync(() async {
            final boundary =
                _previewKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            await Directory('build/task-move-preview').create(recursive: true);
            await File(
              'build/task-move-preview/transfer.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(api.moves.single.data, {
          'projectId': hold ? 'child' : 'p2',
          'status': 'REVIEW',
        });
        expect(find.text('Переместить задачу'), findsNothing);
        expect(result.cubit.state.tasks.any((t) => t.id == 'task'), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed destination loading can retry and a project without columns cannot accept a task',
    (tester) async {
      final api = _Api();
      final result = _setup(api);
      addTearDown(result.cubit.close);
      sl.registerSingleton<TaskMoveRepository>(result.repository);
      await tester.runAsync(() => result.cubit.load('p'));
      await showBoard(tester, result.cubit);
      await openMove(tester);
      api.failProjects = true;
      await select(tester, 'move-workspace-field', 'Личное пространство');
      expect(find.textContaining('Недостаточно прав'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('confirm-task-move')))
            .onPressed,
        isNull,
      );
      api.failProjects = false;
      api.emptyColumns.add('p2');
      await tester.ensureVisible(find.text('Повторить'));
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      await select(tester, 'move-project-field', 'Принимающий проект');
      expect(find.text('В проекте нет доступных колонок.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('confirm-task-move')))
            .onPressed,
        isNull,
      );
      expect(api.moves, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rejection stays in the sheet with selections and usable retry at large text',
    (tester) async {
      final api = _Api()..moveStatus = 403;
      final result = _setup(api);
      addTearDown(result.cubit.close);
      sl.registerSingleton<TaskMoveRepository>(result.repository);
      await tester.runAsync(() => result.cubit.load('p'));
      await showBoard(tester, result.cubit, scale: 1.5);
      await openMove(tester);
      await select(tester, 'move-workspace-field', 'Личное пространство');
      await select(tester, 'move-project-field', 'Принимающий проект');
      await tester.tap(find.byKey(const Key('confirm-task-move')));
      await tester.pumpAndSettle();
      expect(find.text('Переместить задачу'), findsOneWidget);
      expect(find.textContaining('Недостаточно прав'), findsWidgets);
      expect(result.cubit.state.tasks.any((t) => t.id == 'task'), isTrue);
      api.moveStatus = 200;
      await tester.tap(find.byKey(const Key('confirm-task-move')));
      await tester.pumpAndSettle();
      expect(api.moves.length, 2);
      expect(find.text('Переместить задачу'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing workspace ignores a late project response and closing never moves',
    (tester) async {
      final api = _Api();
      final result = _setup(api);
      addTearDown(result.cubit.close);
      sl.registerSingleton<TaskMoveRepository>(result.repository);
      await tester.runAsync(() => result.cubit.load('p'));
      await showBoard(tester, result.cubit);
      await openMove(tester);
      final slow = api.projectGates['w2'] = Completer<void>();
      // An active spinner cannot use pumpAndSettle while this request is blocked.
      await tester.tap(find.byKey(const Key('move-workspace-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Личное пространство').last);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('move-workspace-field')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Другое пространство').last);
      await tester.pumpAndSettle();
      slow.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('move-project-field')));
      await tester.pumpAndSettle();
      expect(find.text('Третий проект'), findsOneWidget);
      expect(find.text('Принимающий проект'), findsNothing);
      await tester.tap(find.text('Третий проект'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Переместить задачу'))).pop();
      await tester.pumpAndSettle();
      expect(api.moves, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
