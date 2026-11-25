import 'package:jospar/features/kanban/presentation/widgets/kanban_board.dart';
import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/auth/auth_session.dart';
import 'package:jospar/core/localization/app_translations.dart';
import 'package:jospar/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:jospar/features/kanban/domain/entities/column_copy_result.dart';
import 'package:jospar/features/kanban/domain/utils/kanban_utils.dart';
import 'package:jospar/features/kanban/presentation/cubit/column_copy_cubit.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_cubit.dart';
import 'package:jospar/features/kanban/presentation/widgets/column_copy_sheet.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Completer<void>? gate;
  final postStarted = Completer<void>();
  int? failure;
  bool timeout = false;
  bool empty = false;
  bool failRefresh = false;
  Completer<void>? refreshGate;
  final refreshStarted = Completer<void>();
  bool created = false;
  int get posts => requests.where((r) => r.method == 'POST').length;
  Map<String, dynamic> get source => {
    'id': 'source',
    'projectId': 'project',
    'name': 'Backlog',
    'statusMap': 'TODO',
    'order': 0,
    'wip': 2,
    'color': '#123456',
  };
  Map<String, dynamic> get copied => {
    'id': 'copied',
    'projectId': 'project',
    'name': 'Backlog (Копия)',
    'statusMap': 'COPY',
    'order': 1,
    'color': '#123456',
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    dynamic data;
    var code = 200;
    if (options.method == 'POST') {
      if (!postStarted.isCompleted) postStarted.complete();
      await gate?.future;
      if (timeout) {
        created = true; // The server can commit even when its response is lost.
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      }
      code = failure ?? 200;
      created = code == 200;
      data = created ? copied : {'message': 'server error'};
    } else if (options.path == 'kanban-columns') {
      if (created && refreshGate != null) {
        if (!refreshStarted.isCompleted) refreshStarted.complete();
        await refreshGate!.future;
      }
      code = failRefresh && created ? 500 : 200;
      data = [
        source,
        if (created) copied,
        {
          'id': 'next',
          'projectId': 'project',
          'name': 'Next',
          'statusMap': 'NEXT',
          'order': 2,
        },
      ];
    } else if (options.path == 'project-tasks') {
      data = [
        if (!empty) ...[
          {
            'id': 'task',
            'projectId': 'project',
            'title': 'Hidden task',
            'status': 'TODO',
          },
          if (created)
            {
              'id': 'task-copy',
              'projectId': 'project',
              'title': 'Hidden task',
              'status': 'COPY',
            },
        ],
      ];
    } else {
      code = 404;
      data = {};
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<KanbanCubit> _board(_Adapter adapter) async {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
    ..httpClientAdapter = adapter;
  final cubit = KanbanCubit(KanbanRepositoryImpl(dio));
  await cubit.load('project');
  return cubit;
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await AppTranslations.load();
  });

  test('copy names normalize edges and case and find the next free suffix', () {
    expect(
      nextColumnCopyName(' Backlog ', [
        ' backlog (копия) ',
        'BACKLOG (КОПИЯ 2)',
      ]),
      'Backlog (Копия 3)',
    );
    expect(nextColumnCopyName('Empty', []), 'Empty (Копия)');
    expect(
      nextColumnCopyName('Жоба', [], copyLabel: 'Көшірме'),
      'Жоба (Көшірме)',
    );
  });

  for (final empty in [false, true]) {
    test(
      'copies ${empty ? 'empty' : 'populated'} column with one POST and reloads all data',
      () async {
        final adapter = _Adapter()..empty = empty;
        final board = await _board(adapter);
        addTearDown(board.close);
        board.setSearch('no matches');
        board.setPriorityFilter('HIGH');
        final source = board.state.columns.first;
        final result = await board.copyColumn(
          source,
          '  New name  ',
          isActive: () => true,
        );
        expect(result.status, ColumnCopyStatus.success);
        final post = adapter.requests.singleWhere((r) => r.method == 'POST');
        expect(post.uri.path, '/api/kanban-columns/source/copy');
        expect(post.data, {'name': 'New name', 'afterColumnId': 'source'});
        expect(adapter.posts, 1);
        expect(board.state.columns.map((c) => c.id), [
          'source',
          'copied',
          'next',
        ]);
        expect(board.state.columns[1].wip, isNull);
        expect(board.state.columns[1].color, source.color);
        expect(board.state.tasks.length, empty ? 0 : 2);
        expect(board.state.search, 'no matches');
        expect(board.state.tasksFor(board.state.columns[1]), isEmpty);
      },
    );
  }

  test('empty name and double submit cannot send duplicate requests', () async {
    final adapter = _Adapter()..gate = Completer<void>();
    final board = await _board(adapter);
    addTearDown(board.close);
    final form = ColumnCopyCubit(board, board.state.columns.first, () => true);
    addTearDown(form.close);
    await form.submit('   ');
    expect(form.state.status, ColumnCopyStatus.failure);
    expect(adapter.posts, 0);
    final first = form.submit('Name');
    await adapter.postStarted.future;
    await form.submit('Name');
    expect(adapter.posts, 1);
    adapter.gate!.complete();
    await first;
    expect(form.state.status, ColumnCopyStatus.success);
  });

  for (final code in [400, 403, 404, 409, 410, 412, 422, 500]) {
    test(
      'HTTP $code preserves typed error, refreshes access and never retries POST',
      () async {
        final adapter = _Adapter()..failure = code;
        final board = await _board(adapter);
        addTearDown(board.close);
        final form = ColumnCopyCubit(
          board,
          board.state.columns.first,
          () => true,
        );
        addTearDown(form.close);
        await form.submit('Name');
        expect(adapter.posts, 1);
        expect(form.state.message, isNotEmpty);
        expect(
          form.state.status,
          code == 400
              ? ColumnCopyStatus.failure
              : code == 403
              ? ColumnCopyStatus.forbidden
              : code == 500
              ? ColumnCopyStatus.uncertain
              : ColumnCopyStatus.stale,
        );
        if (code == 403) expect(board.state.columnCopyDenied, isTrue);
        if (code != 400) {
          await form.refresh();
          await form.submit('Name');
          expect(adapter.posts, 1);
        }
      },
    );
  }

  test('timeout reconciles board first and blocks another POST', () async {
    final adapter = _Adapter()..timeout = true;
    final board = await _board(adapter);
    addTearDown(board.close);
    final form = ColumnCopyCubit(board, board.state.columns.first, () => true);
    addTearDown(form.close);
    await form.submit('Name');
    expect(form.state.status, ColumnCopyStatus.uncertain);
    expect(board.state.columns.any((c) => c.id == 'copied'), isTrue);
    await form.submit('Name');
    await form.refresh();
    expect(adapter.posts, 1);
  });

  for (final change in ['project', 'account', 'screen', 'form', 'board']) {
    test('ignores delayed response after $change change', () async {
      final adapter = _Adapter()..gate = Completer<void>();
      final board = await _board(adapter);
      var active = true;
      final form = ColumnCopyCubit(
        board,
        board.state.columns.first,
        () => active,
      );
      final pending = form.submit('Name');
      await adapter.postStarted.future;
      if (change == 'project') await board.load('other');
      if (change == 'account') authSession.markAuthenticated();
      if (change == 'screen') active = false;
      if (change == 'form') await form.close();
      if (change == 'board') await board.close();
      final before = board.state;
      final requests = adapter.requests.length;
      adapter.gate!.complete();
      await pending;
      expect(board.state, before);
      expect(adapter.requests.length, requests);
      if (!form.isClosed) await form.close();
      if (!board.isClosed) await board.close();
    });
  }

  test(
    'closing screen during reconciliation ignores its late board response',
    () async {
      final adapter = _Adapter()..refreshGate = Completer<void>();
      final board = await _board(adapter);
      addTearDown(board.close);
      var active = true;
      final pending = board.copyColumn(
        board.state.columns.first,
        'Name',
        isActive: () => active,
      );
      await adapter.refreshStarted.future;
      final before = board.state;
      active = false;
      adapter.refreshGate!.complete();
      expect((await pending).status, ColumnCopyStatus.cancelled);
      expect(board.state, before);
    },
  );

  test(
    'refresh failure keeps authoritative copied column without another POST',
    () async {
      final adapter = _Adapter()..failRefresh = true;
      final board = await _board(adapter);
      addTearDown(board.close);
      final result = await board.copyColumn(
        board.state.columns.first,
        'Name',
        isActive: () => true,
      );
      expect(result.status, ColumnCopyStatus.success);
      expect(board.state.columns.map((c) => c.id), [
        'source',
        'copied',
        'next',
      ]);
      expect(board.state.actionErrorMessage, isNotNull);
      expect(adapter.posts, 1);
    },
  );

  testWidgets('column menu opens copy form and scrolls to synchronized copy', (
    tester,
  ) async {
    final adapter = _Adapter();
    final board = (await tester.runAsync(() => _board(adapter)))!;
    addTearDown(board.close);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: board,
            child: const KanbanBoard(
              project: ProjectModel(
                id: 'project',
                code: 'P',
                name: 'Project',
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
    await tester.tap(find.byTooltip('Действия колонки').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Копировать колонку'));
    await tester.pumpAndSettle();
    expect(find.byType(ColumnCopySheet), findsOneWidget);
    await tester.tap(find.text('Копировать'));
    await tester.pumpAndSettle();
    expect(adapter.posts, 1);
    expect(find.text('Колонка скопирована'), findsOneWidget);
    expect(board.state.tasks.any((t) => t.id == 'task-copy'), isTrue);
    final pager = tester.widget<PageView>(find.byType(PageView).first);
    expect(pager.controller!.page, closeTo(1, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing copy sheet during POST ignores late result', (
    tester,
  ) async {
    final adapter = _Adapter()..gate = Completer<void>();
    final board = (await tester.runAsync(() => _board(adapter)))!;
    addTearDown(board.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: board,
            child: const KanbanBoard(
              project: ProjectModel(
                id: 'project',
                code: 'P',
                name: 'Project',
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
    await tester.tap(find.byTooltip('Действия колонки').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Копировать колонку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Копировать'));
    await tester.pump();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    final before = board.state;
    adapter.gate!.complete();
    await tester.pumpAndSettle();
    expect(board.state, before);
    expect(find.text('Колонка скопирована'), findsNothing);
    expect(adapter.posts, 1);
    expect(tester.takeException(), isNull);
  });

  Future<void> pumpForm(
    WidgetTester tester,
    ColumnCopyCubit form, {
    String locale = 'ru',
    bool compact = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        supportedLocales: const [Locale('ru'), Locale('kk')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => BlocProvider.value(
                  value: form,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(compact ? 2 : 1),
                      viewInsets: EdgeInsets.only(bottom: compact ? 250 : 0),
                    ),
                    child: const ColumnCopySheet(),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'form validates, retains failed name, retries and blocks double taps',
    (tester) async {
      final adapter = _Adapter()..failure = 400;
      final board = (await tester.runAsync(() => _board(adapter)))!;
      addTearDown(board.close);
      final form = ColumnCopyCubit(
        board,
        board.state.columns.first,
        () => true,
      );
      addTearDown(form.close);
      await pumpForm(tester, form);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Backlog (Копия)',
      );
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text('Копировать'));
      await tester.pumpAndSettle();
      expect(find.text('Введите название новой колонки'), findsOneWidget);
      expect(adapter.posts, 0);
      await tester.enterText(find.byType(TextFormField), ' Edited ');
      await tester.tap(find.text('Копировать'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('column-copy-error')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        ' Edited ',
      );
      adapter.failure = null;
      adapter.gate = Completer<void>();
      await tester.tap(find.text('Копировать'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      adapter.gate!.complete();
      await tester.pumpAndSettle();
      expect(adapter.posts, 2);
      expect(find.byType(ColumnCopySheet), findsNothing);
    },
  );

  testWidgets('compact Kazakh sheet supports keyboard and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final board = (await tester.runAsync(() => _board(_Adapter())))!;
    addTearDown(board.close);
    final form = ColumnCopyCubit(board, board.state.columns.first, () => true);
    addTearDown(form.close);
    await pumpForm(tester, form, locale: 'kk', compact: true);
    expect(
      find.text(AppTranslations.translate('Копировать колонку', 'kk')),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'Backlog (${AppTranslations.translate('Копия', 'kk')})',
    );
    await tester.ensureVisible(find.byType(TextFormField));
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
