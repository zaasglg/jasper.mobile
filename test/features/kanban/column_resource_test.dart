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
import 'package:jospar/features/kanban/domain/entities/resource_pair_total.dart';
import 'package:jospar/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:jospar/features/kanban/presentation/cubit/column_resource_cubit.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_cubit.dart';
import 'package:jospar/features/kanban/presentation/widgets/column_resource_sheet.dart';
import 'package:jospar/features/kanban/presentation/widgets/kanban_board.dart';
import 'package:jospar/features/projects/data/models/project_task_dto.dart';
import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'package:jospar/features/projects/domain/entities/project_task_model.dart';
import 'package:jospar/features/tasks/data/repositories/task_details_repository_impl.dart';
import 'package:jospar/features/tasks/domain/entities/task_resource_model.dart';
import 'package:jospar/features/tasks/domain/repositories/task_details_repository.dart';

TaskResourceModel resource(
  String name,
  int order, {
  double plan = 0,
  double fact = 0,
}) => TaskResourceModel(
  id: '$name$order',
  name: name,
  order: order,
  planValue: plan,
  factValue: fact,
);
List<TaskResourceModel> pair({
  String planName = 'План',
  String factName = 'Факт',
  double plan = 100,
  double fact = 50,
}) => [
  resource(planName, 0, plan: plan, fact: 999),
  resource(factName, 1, plan: 999, fact: fact),
];
ProjectTaskModel task(String id, {List<TaskResourceModel>? resources}) =>
    ProjectTaskModel(
      id: id,
      projectId: 'project',
      status: 'TODO',
      resources: resources,
    );

class _Reader implements TaskResourceReadRepository {
  final calls = <String>[];
  final Map<String, Completer<void>> gates = {};
  final Set<String> failures = {};
  int active = 0;
  int maxActive = 0;
  @override
  Future<List<TaskResourceModel>> getResources(String taskId) async {
    calls.add(taskId);
    active++;
    if (active > maxActive) maxActive = active;
    try {
      await gates[taskId]?.future;
      if (failures.contains(taskId)) {
        throw const TaskDetailsException('unavailable');
      }
      return pair();
    } finally {
      active--;
    }
  }
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool failSecondPage = false;
  bool failResource = false;
  bool forbidden = false;
  dynamic resourceResponse;
  int taskCount = 101;
  bool inline = true;
  Map<String, dynamic> row(int i) => {
    'id': 't$i',
    'projectId': 'project',
    'status': 'TODO',
    'title': i == 0 ? 'visible' : 'other',
    'resourcesCount': 2,
    if (inline) 'resources': pair().map((r) => r.toJson()).toList(),
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    dynamic data;
    var status = 200;
    if (options.path == 'project-tasks') {
      final skip = options.queryParameters['skip'] as int;
      if (skip > 0 && failSecondPage) {
        status = 500;
        data = {};
      } else {
        data = List.generate(taskCount, row).skip(skip).take(100).toList();
      }
    } else if (options.path == 'kanban-columns') {
      data = [
        {
          'id': 'column',
          'name': 'Backlog',
          'statusMap': 'TODO',
          'projectId': 'project',
          'order': 0,
        },
      ];
    } else if (options.path.startsWith('tasks/')) {
      status = forbidden
          ? 403
          : failResource
          ? 500
          : 200;
      data = resourceResponse ?? pair().map((r) => r.toJson()).toList();
    } else {
      status = 404;
      data = {};
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Adapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
      ..httpClientAdapter = adapter;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await AppTranslations.load();
  });

  test(
    'aggregates matching name pairs across tasks and keeps different pairs separate',
    () {
      final totals = summarizeTaskResourcePairs([
        [
          ...pair(planName: ' Budget ', factName: 'Spent', plan: 100, fact: 40),
          ...pair(
            planName: 'Hours',
            factName: 'Actual hours',
            plan: 20,
            fact: 30,
          ).map((r) => r.copyWith(order: r.order + 2)),
        ],
        pair(planName: 'Budget', factName: 'Spent', plan: 200, fact: 80),
        pair(planName: 'Budget', factName: 'Different', plan: 10, fact: 2),
        pair(planName: 'budget', factName: 'Spent', plan: 5, fact: 1),
      ]);
      expect(totals, hasLength(4));
      expect(totals.first.plan, 300);
      expect(totals.first.fact, 120);
      expect(totals.first.percentage, 40);
      expect(totals[1].percentage, 150);
      expect(totals[1].progress, 1);
    },
  );

  test(
    'sorts resources stably by order, skips unmatched rows and never pairs across tasks',
    () {
      final totals = summarizeTaskResourcePairs([
        [
          resource('orphan', 10, plan: 999),
          resource('Fact', 2, fact: 25),
          resource('Plan', 1, plan: 50),
        ],
        [resource('single', 0, fact: 999)],
      ]);
      expect(totals.single.plan, 50);
      expect(totals.single.fact, 25);
      expect(totals.single.planName, 'Plan');
      expect(
        summarizeTaskResourcePairs([
          [resource('one', 0)],
          [resource('two', 0)],
        ]),
        isEmpty,
      );
    },
  );

  test(
    'localized fallback names, zero plans, negatives and percentages over 100',
    () {
      final total = summarizeTaskResourcePairs(
        [pair(planName: ' ', factName: '', plan: 0, fact: 10)],
        planFallback: 'Жоспар',
        factFallback: 'Нақты',
      ).single;
      expect(total.planName, 'Жоспар');
      expect(total.factName, 'Нақты');
      expect(total.percentage, 0);
      expect(total.copyWith(plan: -1).percentage, 0);
      expect(total.copyWith(plan: 10, fact: -1).percentage, 0);
      expect(total.copyWith(plan: 10, fact: 25).percentage, 250);
      expect(total.copyWith(plan: 10, fact: 25).progress, 1);
    },
  );

  test(
    'task DTO retains omitted versus empty resources through conversion and serialization',
    () {
      final adapter = _Adapter();
      final full = ProjectTaskDto.fromJson(adapter.row(0));
      expect(full.resources, hasLength(2));
      expect(full.toEntity().resources, full.resources);
      expect(
        ProjectTaskDto.fromEntity(full.toEntity()).toJson()['resources'],
        full.toJson()['resources'],
      );
      expect(full.copyWith(title: 'edit').resources, full.resources);
      expect(full.toEntity().copyWith(title: 'edit').resources, full.resources);
      expect(
        ProjectTaskDto.fromJson({...adapter.row(0), 'resources': []}).resources,
        isEmpty,
      );
      adapter.inline = false;
      expect(ProjectTaskDto.fromJson(adapter.row(0)).resources, isNull);
    },
  );

  test(
    'uses inline resources including authoritative empty lists without extra GETs',
    () async {
      final reader = _Reader();
      final cubit = ColumnResourceCubit(
        tasks: [
          task('a', resources: pair()),
          task('empty', resources: []),
        ],
        repository: reader,
        isScopeActive: () => true,
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(reader.calls, isEmpty);
      expect(cubit.state.status, ColumnResourceStatus.success);
      expect(cubit.state.taskCount, 2);
      expect(cubit.state.pairs.single.fact, 50);
    },
  );

  test('empty column succeeds without requests', () async {
    final reader = _Reader();
    final cubit = ColumnResourceCubit(
      tasks: [],
      repository: reader,
      isScopeActive: () => true,
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.status, ColumnResourceStatus.success);
    expect(cubit.state.pairs, isEmpty);
    expect(cubit.state.taskCount, 0);
    expect(reader.calls, isEmpty);
  });

  test('bounds concurrency at four and publishes no partial summary', () async {
    final reader = _Reader();
    for (var i = 0; i < 9; i++) {
      reader.gates['$i'] = Completer<void>();
    }
    final cubit = ColumnResourceCubit(
      tasks: List.generate(9, (i) => task('$i')),
      repository: reader,
      isScopeActive: () => true,
    );
    addTearDown(cubit.close);
    final pending = cubit.load();
    await Future<void>.delayed(Duration.zero);
    expect(reader.calls.length, 4);
    expect(cubit.state.pairs, isEmpty);
    reader.gates['0']!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(reader.calls.length, 5);
    expect(cubit.state.status, ColumnResourceStatus.loading);
    for (final gate in reader.gates.values) {
      if (!gate.isCompleted) gate.complete();
    }
    await pending;
    expect(reader.maxActive, 4);
    expect(cubit.state.taskCount, 9);
    expect(cubit.state.pairs.single.plan, 900);
  });

  test(
    'failed per-task load hides every total and retry reloads complete snapshot',
    () async {
      final reader = _Reader()..failures.add('bad');
      final cubit = ColumnResourceCubit(
        tasks: [
          task('inline', resources: pair()),
          task('bad'),
        ],
        repository: reader,
        isScopeActive: () => true,
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.status, ColumnResourceStatus.failure);
      expect(cubit.state.pairs, isEmpty);
      reader.failures.clear();
      await cubit.load();
      expect(cubit.state.status, ColumnResourceStatus.success);
      expect(cubit.state.pairs.single.plan, 200);
    },
  );

  test(
    'partial inline resources fall back to authoritative endpoint',
    () async {
      final reader = _Reader();
      final cubit = ColumnResourceCubit(
        tasks: [task('a', resources: []).copyWith(resourceCount: 2)],
        repository: reader,
        isScopeActive: () => true,
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(reader.calls, ['a']);
      expect(cubit.state.pairs.single.plan, 100);
    },
  );

  for (final change in ['close', 'account', 'project']) {
    test(
      'ignores late resource responses and stops queued GETs after $change',
      () async {
        final reader = _Reader();
        for (var i = 0; i < 6; i++) {
          reader.gates['$i'] = Completer<void>();
        }
        var active = true;
        final scope = StreamController<Object?>.broadcast(sync: true);
        final cubit = ColumnResourceCubit(
          tasks: List.generate(6, (i) => task('$i')),
          repository: reader,
          isScopeActive: () => active,
          scopeChanges: scope.stream,
        );
        final pending = cubit.load();
        await Future<void>.delayed(Duration.zero);
        if (change == 'close') await cubit.close();
        if (change == 'account') authSession.markAuthenticated();
        if (change == 'project') {
          active = false;
          scope.add(null);
        }
        for (final gate in reader.gates.values) {
          gate.complete();
        }
        await pending;
        expect(cubit.state.pairs, isEmpty);
        expect(reader.calls.length, 4);
        if (!cubit.isClosed) await cubit.close();
        await scope.close();
      },
    );
  }

  test(
    'pagination completes before summary and includes tasks past first 100',
    () async {
      final adapter = _Adapter();
      final repository = KanbanRepositoryImpl(_dio(adapter));
      final data = await repository.loadBoard('project');
      final reader = _Reader();
      final cubit = ColumnResourceCubit(
        tasks: data.tasks,
        repository: reader,
        isScopeActive: () => true,
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(
        adapter.requests
            .where((r) => r.path == 'project-tasks')
            .map((r) => r.queryParameters['skip']),
        [0, 100],
      );
      expect(cubit.state.taskCount, 101);
      expect(cubit.state.pairs.single.plan, 10100);
      expect(reader.calls, isEmpty);
      expect(adapter.requests.every((r) => r.method == 'GET'), isTrue);
    },
  );

  test('failed later task page never exposes a partial board', () async {
    final adapter = _Adapter()..failSecondPage = true;
    final board = KanbanCubit(KanbanRepositoryImpl(_dio(adapter)));
    addTearDown(board.close);
    await board.load('project');
    expect(board.state.tasks, isEmpty);
    expect(board.state.errorMessage, isNotNull);
  });

  test(
    'resource reader uses existing baseUrl, handles wrappers, malformed data and access errors',
    () async {
      final adapter = _Adapter();
      final repository = TaskDetailsRepositoryImpl(_dio(adapter));
      expect(await repository.getResources('task'), hasLength(2));
      expect(adapter.requests.single.uri.path, '/api/tasks/task/resources');
      adapter.resourceResponse = {
        'data': {'items': []},
      };
      expect(await repository.getResources('task'), isEmpty);
      adapter.resourceResponse = {'bad': true};
      await expectLater(
        repository.getResources('task'),
        throwsA(isA<TaskDetailsException>()),
      );
      adapter.forbidden = true;
      await expectLater(
        repository.getResources('task'),
        throwsA(
          isA<TaskDetailsException>().having(
            (e) => e.message,
            'message',
            'Недостаточно прав для просмотра ресурсов',
          ),
        ),
      );
      expect(adapter.requests.every((r) => r.method == 'GET'), isTrue);
    },
  );

  Future<void> pumpSheet(
    WidgetTester tester,
    ColumnResourceCubit cubit, {
    String locale = 'ru',
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        supportedLocales: const [Locale('ru'), Locale('kk')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(brightness: brightness),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                useSafeArea: true,
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: BlocProvider.value(
                    value: cubit,
                    child: const ColumnResourceSheet(
                      columnName: 'Длинное название колонки',
                    ),
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('loading, error, retry, summary and close are read-only', (
    tester,
  ) async {
    final reader = _Reader()
      ..gates['a'] = Completer<void>()
      ..failures.add('a');
    final cubit = ColumnResourceCubit(
      tasks: [task('a')],
      repository: reader,
      isScopeActive: () => true,
    );
    addTearDown(cubit.close);
    final pending = cubit.load();
    await pumpSheet(tester, cubit);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    reader.gates['a']!.complete();
    await pending;
    await tester.pumpAndSettle();
    expect(
      find.text('Не удалось загрузить ресурсы. Повторите попытку.'),
      findsOneWidget,
    );
    expect(find.byType(ResourcePairBar), findsNothing);
    reader.failures.clear();
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.byType(ResourcePairBar), findsOneWidget);
    expect(find.text('1 задач'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.byType(ColumnResourceSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state includes task count', (tester) async {
    final cubit = ColumnResourceCubit(
      tasks: [],
      repository: null,
      isScopeActive: () => true,
    );
    addTearDown(cubit.close);
    await cubit.load();
    await pumpSheet(tester, cubit);
    expect(find.text('Нет данных ресурса'), findsOneWidget);
    expect(find.text('0 задач'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('320px, 200 percent text, locale kk, $brightness theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = ColumnResourceCubit(
        tasks: [
          task(
            'a',
            resources: pair(
              planName: 'Очень длинное пользовательское название плана',
              factName: 'Название фактического показателя',
              plan: 1234.567,
              fact: 2345.678,
            ),
          ),
        ],
        repository: null,
        isScopeActive: () => true,
      );
      addTearDown(cubit.close);
      await cubit.load();
      await pumpSheet(
        tester,
        cubit,
        locale: 'kk',
        brightness: brightness,
        textScale: 2,
      );
      expect(
        find.text('Очень длинное пользовательское название плана'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byType(LinearProgressIndicator));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        1,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'percentage text rounds to one decimal, amount to two, bar caps at 100',
    (tester) async {
      final cubit = ColumnResourceCubit(
        tasks: [task('a', resources: pair(plan: 100, fact: 150.456))],
        repository: null,
        isScopeActive: () => true,
      );
      addTearDown(cubit.close);
      await cubit.load();
      await pumpSheet(tester, cubit);
      expect(find.text('150,5%'), findsOneWidget);
      expect(find.text('150,46'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        1,
      );
    },
  );

  testWidgets(
    'column menu summarizes visible filtered tasks only with no resource GET',
    (tester) async {
      final adapter = _Adapter()..taskCount = 3;
      final board = KanbanCubit(KanbanRepositoryImpl(_dio(adapter)));
      addTearDown(board.close);
      await tester.runAsync(() => board.load('project'));
      board.setSearch('visible');
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
                  workspaceId: 'w',
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
      await tester.tap(find.text('Ресурс'));
      await tester.pumpAndSettle();
      expect(find.byType(ColumnResourceSheet), findsOneWidget);
      expect(find.text('1 задач'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(
        adapter.requests.where((r) => r.path.startsWith('tasks/')),
        isEmpty,
      );
      expect(adapter.requests.every((r) => r.method == 'GET'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
