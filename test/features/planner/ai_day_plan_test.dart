import 'package:jospar/features/assistant/presentation/widgets/assistant_web_layout.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';
import 'package:jospar/features/planner/presentation/screens/planner_screen.dart';
import 'planner_test_app.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/assistant/domain/entities/assistant_request.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/data/repositories/ai_day_plan_repository_impl.dart';
import 'package:jospar/features/planner/domain/entities/ai_day_plan_entry.dart';
import 'package:jospar/features/planner/domain/repositories/ai_day_plan_repository.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/presentation/cubit/ai_day_plan_cubit.dart';
import 'package:jospar/features/planner/presentation/widgets/ai_day_plan_sheet.dart';

const first = AiDayPlanEntry(
  taskId: 'a',
  projectId: 'p',
  title: 'Сдать отчёт',
  reason: 'Срок сегодня',
);
const second = AiDayPlanEntry(
  taskId: 'b',
  projectId: 'p',
  title: 'Проверить макет',
  reason: 'Высокий приоритет',
);
final day = DateTime(2026, 11, 24);

void main() {
  late _Suggestions suggestions;
  late _Planner planner;
  late AiDayPlanCubit cubit;
  var scope = true;
  AiDayPlanCubit makeCubit() => AiDayPlanCubit(
    repository: suggestions,
    planner: planner,
    workspaceId: 'w',
    day: day,
    now: () => day.add(const Duration(hours: 8)),
    scopeIsCurrent: () async => scope,
  );
  setUp(() {
    suggestions = _Suggestions();
    planner = _Planner();
    scope = true;
    cubit = makeCubit();
  });
  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  testWidgets(
    'AI chat composer opens proposal and cancelling performs no writes',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'test-session',
        'selected_workspace_id': 'w',
      });
      const secure = FlutterSecureStorage();
      sl.registerSingleton<WorkspaceSelectionStorage>(
        const WorkspaceSelectionStorage(secure),
      );
      sl.registerSingleton<AuthTokenStorage>(AuthTokenStorage(secure));
      sl.registerSingleton<AiDayPlanRepository>(suggestions);
      sl.registerSingleton<PlannerRepository>(planner);
      addTearDown(sl.reset);
      final plannerCubit = PlannerCubit(planner);
      addTearDown(plannerCubit.close);
      await tester.pumpWidget(
        PlannerTestApp(
          child: BlocProvider.value(
            value: plannerCubit,
            child: const MaterialApp(home: PlannerScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('planner-next-day')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('planner-ai-day-plan')), findsNothing);
      final input = TextEditingController();
      final focus = FocusNode();
      addTearDown(input.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => AssistantWebComposer(
                input: input,
                focus: focus,
                enabled: true,
                sending: false,
                listening: false,
                picking: false,
                attachments: const [],
                onSend: () {},
                onVoice: () {},
                onAttach: () {},
                onRemove: (_) {},
                onDayPlan: () => showAiDayPlan(context),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('assistant-ai-day-plan')));
      await tester.pumpAndSettle();
      expect(find.byType(AiDayPlanSheet), findsOneWidget);
      expect(find.text(first.title), findsOneWidget);
      await tester.tap(find.byTooltip('Закрыть').last);
      await tester.pumpAndSettle();
      expect(find.byType(AiDayPlanSheet), findsNothing);
      expect(planner.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('proposal remains usable with large text on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: Scaffold(body: AiDayPlanSheet())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-day-plan-confirm')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'generation is read-only; confirmation saves only selected edited links',
    () async {
      await cubit.generate();
      expect(planner.calls, isEmpty);
      cubit.edit(first.copyWith(durationMinutes: 60, startMinute: 600));
      cubit.edit(second.copyWith(selected: false));
      await cubit.confirm();
      expect(planner.calls, ['a']);
      expect(planner.lastTime, DateTime(2026, 11, 24, 10).toUtc());
      expect(planner.lastDuration, 60);
      expect(cubit.state.status, AiDayPlanStatus.complete);
      await cubit.confirm();
      expect(planner.calls, ['a']);
    },
  );

  test(
    'partial save remains editable and retry never repeats successful link',
    () async {
      await cubit.generate();
      planner.failOn = 'b';
      final states = <AiDayPlanState>[];
      final subscription = cubit.stream.listen(states.add);
      await cubit.confirm();
      expect(cubit.state.entries.first.saved, isTrue);
      expect(cubit.state.entries.last.saved, isFalse);
      expect(cubit.state.error, isNotNull);
      // Previously emitted snapshots must not mutate when the next task is saved.
      expect(states.first.entries.first.saved, isFalse);
      planner.failOn = null;
      await cubit.confirm();
      expect(planner.calls, ['a', 'b', 'b']);
      expect(cubit.state.status, AiDayPlanStatus.complete);
      await subscription.cancel();
    },
  );

  test(
    'refresh before confirmation preserves an existing plan on any day',
    () async {
      await cubit.generate();
      planner.items.add(
        PlannerItemModel(
          id: 'old',
          title: first.title,
          taskId: 'a',
          plannedDate: DateTime(2026, 11, 25),
        ),
      );
      await cubit.confirm();
      expect(planner.calls, ['b']);
      expect(cubit.state.entries.first.saved, isTrue);
    },
  );

  test(
    'scope change blocks writes and discards a delayed suggestion',
    () async {
      suggestions.pending = Completer<List<AiDayPlanEntry>>();
      final loading = cubit.generate();
      await Future<void>.delayed(Duration.zero);
      scope = false;
      suggestions.pending!.complete([first]);
      await loading;
      expect(cubit.state.status, AiDayPlanStatus.failure);
      expect(cubit.state.entries, isEmpty);
      expect(planner.calls, isEmpty);
    },
  );

  test('scope change between linked writes stops the remaining plan', () async {
    await cubit.generate();
    planner.afterAdd = () => scope = false;
    await cubit.confirm();
    expect(planner.calls, ['a']);
    expect(cubit.state.error, contains('пространство'));
    expect(cubit.state.entries.first.saved, isTrue);
  });

  test(
    'overlapping times and past times are rejected before any write',
    () async {
      await cubit.generate();
      cubit.edit(first.copyWith(startMinute: 600));
      cubit.edit(second.copyWith(startMinute: 610));
      await cubit.confirm();
      expect(cubit.state.error, contains('пересекается'));
      expect(planner.calls, isEmpty);
      cubit.edit(second.copyWith(startMinute: 900));
      planner.items.add(
        PlannerItemModel(
          id: 'meeting',
          title: 'Встреча',
          scheduledAt: DateTime(2026, 11, 24, 10, 15).toUtc(),
        ),
      );
      await cubit.confirm();
      expect(cubit.state.error, contains('занято'));
      expect(planner.calls, isEmpty);
      cubit.edit(first.copyWith(startMinute: 400));
      await cubit.confirm();
      expect(cubit.state.error, contains('позже текущего'));
      expect(planner.calls, isEmpty);
    },
  );

  test('closing cancels inference and ignores its late response', () async {
    suggestions.pending = Completer<List<AiDayPlanEntry>>();
    final pending = cubit.generate();
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    expect(suggestions.request!.isCancelled, isTrue);
    suggestions.pending!.complete([first]);
    await pending;
    expect(planner.calls, isEmpty);
  });

  test('midnight rollover requires a fresh proposal before writing', () async {
    var now = day.add(const Duration(hours: 23));
    final midnightCubit = AiDayPlanCubit(
      repository: suggestions,
      planner: planner,
      workspaceId: 'w',
      day: day,
      scopeIsCurrent: () async => true,
      now: () => now,
    );
    addTearDown(midnightCubit.close);
    await midnightCubit.generate();
    now = day.add(const Duration(days: 1));
    await midnightCubit.confirm();
    expect(midnightCubit.state.error, contains('новый день'));
    expect(planner.calls, isEmpty);
  });

  test('duplicate confirmation taps start only one save', () async {
    await cubit.generate();
    planner.pending = Completer<void>();
    final saving = cubit.confirm();
    await cubit.confirm();
    planner.pending!.complete();
    await saving;
    expect(planner.calls, ['a', 'b']);
  });

  test(
    'API checks date, duplicate ids, unknown schema and transport error',
    () async {
      final dio = Dio();
      final adapter = _Adapter({
        'date': '2026-11-24',
        'items': [first.toJson()],
      });
      dio.httpClientAdapter = adapter;
      final repository = AiDayPlanRepositoryImpl(dio);
      Future<List<AiDayPlanEntry>> load() => repository.suggest(
        workspaceId: 'w',
        day: day,
        request: AssistantRequest(),
      );
      expect(await load(), [first]);
      expect(adapter.options?.path, 'ai/assistant/day-plan');
      expect(adapter.options?.headers['X-Workspace-Id'], 'w');
      for (final payload in [
        {
          'date': '2026-11-25',
          'items': [first.toJson()],
        },
        {
          'date': '2026-11-24',
          'items': [first.toJson(), first.toJson()],
        },
        {
          'date': '2026-11-24',
          'items': [
            {'taskId': 'invented'},
          ],
        },
        {
          'date': '2026-11-24',
          'items': [
            {...first.toJson(), 'durationMinutes': 999},
          ],
        },
      ]) {
        adapter.body = payload;
        await expectLater(load(), throwsA(isA<AiDayPlanException>()));
      }
      adapter.status = 404;
      await expectLater(
        load(),
        throwsA(
          isA<AiDayPlanException>().having(
            (e) => e.message,
            'message',
            contains('обновление сервера'),
          ),
        ),
      );
    },
  );

  testWidgets(
    'sheet shows proposal, edits selection, and saves only on confirm at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: const MaterialApp(home: Scaffold(body: AiDayPlanSheet())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(first.title), findsOneWidget);
      expect(find.text(first.reason), findsOneWidget);
      expect(planner.calls, isEmpty);
      await tester.tap(find.text(second.title));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ai-day-plan-confirm')));
      await tester.pumpAndSettle();
      expect(planner.calls, ['a']);
      expect(find.text('Готово'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Suggestions implements AiDayPlanRepository {
  Completer<List<AiDayPlanEntry>>? pending;
  AssistantRequest? request;
  @override
  Future<List<AiDayPlanEntry>> suggest({
    required String workspaceId,
    required DateTime day,
    required AssistantRequest request,
  }) async {
    this.request = request;
    return pending == null ? [first, second] : pending!.future;
  }
}

class _Planner implements PlannerRepository {
  final calls = <String>[];
  final items = <PlannerItemModel>[];
  String? failOn;
  Completer<void>? pending;
  VoidCallback? afterAdd;
  DateTime? lastTime;
  int? lastDuration;
  @override
  Future<List<PlannerItemModel>> load() async => [...items];
  @override
  Future<void> addTask({
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime? scheduledAt,
    DateTime? plannedDate,
    required int durationMinutes,
  }) async {
    calls.add(taskId!);
    await pending?.future;
    if (taskId == failOn) throw const PlannerException('Ошибка сохранения');
    items.add(
      PlannerItemModel(
        id: taskId,
        taskId: taskId,
        title: '',
        scheduledAt: scheduledAt,
        plannedDate: plannedDate,
      ),
    );
    lastTime = scheduledAt;
    lastDuration = durationMinutes;
    afterAdd?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);
  Object body;
  int status = 200;
  RequestOptions? options;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
