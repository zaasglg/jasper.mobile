import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'package:jospar/features/projects/domain/entities/project_task_model.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/inbox/domain/entities/inbox_task_model.dart';
import 'package:jospar/features/inbox/presentation/screens/inbox_screen.dart';
import 'package:jospar/features/kanban/presentation/widgets/task_card.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/domain/utils/planner_dates.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';
import 'package:jospar/features/planner/presentation/screens/planner_screen.dart';
import 'package:jospar/features/tasks/domain/entities/kanban_column_model.dart';
import 'package:jospar/features/tasks/domain/entities/task_extra_field.dart';
import 'package:jospar/features/tasks/domain/repositories/my_task_fields_storage.dart';
import 'package:jospar/features/tasks/domain/repositories/my_tasks_repository.dart';
import 'package:jospar/features/tasks/presentation/cubit/my_tasks_cubit.dart';
import 'package:jospar/features/tasks/presentation/widgets/my_tasks_widget.dart';

const _task = ProjectTaskModel(
  id: 'task',
  displayId: 'ORB-24',
  projectId: 'project',
  status: 'TODO',
  title: 'Подготовить презентацию проекта',
);
const _inbox = InboxTaskModel(
  id: 'inbox',
  title: 'Подготовить презентацию проекта',
);
const _capture = bool.fromEnvironment('CAPTURE_PLANNER_PREVIEWS');
final _previewKey = GlobalKey();

class _Planner implements PlannerRepository {
  List<PlannerItemModel> items = [];
  int writes = 0;
  String? taskId, inboxId, projectId;
  DateTime? scheduledAt;
  int? duration;
  bool fail = false;
  bool failLoad = false;
  Completer<void>? loadGate;

  @override
  Future<List<PlannerItemModel>> load() async {
    await loadGate?.future;
    if (failLoad) {
      throw const PlannerException('Не удалось загрузить ежедневник.');
    }
    return [...items];
  }

  @override
  Future<void> addTask({
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime? scheduledAt,
    DateTime? plannedDate,
    required int durationMinutes,
  }) async {
    writes++;
    if (fail) {
      throw const PlannerException('Не удалось сохранить. Повторите попытку.');
    }
    this.projectId = projectId;
    this.taskId = taskId;
    inboxId = inboxTaskId;
    this.scheduledAt = scheduledAt;
    duration = durationMinutes;
    items.add(
      PlannerItemModel(
        id: 'new-slot',
        title: _task.title,
        projectId: projectId,
        taskId: taskId,
        inboxTaskId: inboxTaskId,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
      ),
    );
  }

  @override
  Future<void> update(
    PlannerItemModel item, {
    String? title,
    DateTime? scheduledAt,
    DateTime? plannedDate,
    int? durationMinutes,
    bool? completed,
  }) async {
    writes++;
    this.scheduledAt = scheduledAt;
    duration = durationMinutes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tasks implements MyTasksRepository, MyTaskFieldsStorage {
  @override
  Future<List<ProjectTaskModel>> getTasks({
    required String assigneeId,
    List<String> projectIds = const [],
  }) async => [_task];
  @override
  Future<List<KanbanColumnModel>> getKanbanColumns(String projectId) async =>
      [];
  @override
  Future<Set<TaskExtraField>> read() async => {};
  @override
  Future<void> save(Set<TaskExtraField> fields) async {}
  @override
  Future<void> updateProgress(
    String taskId,
    int progress, {
    String? status,
  }) async {}
}

Future<void> _capturePreview(WidgetTester tester, String name) async {
  if (!_capture) return;
  final boundary =
      _previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final dir = Directory('.dart_tool/planner_previews')
      ..createSync(recursive: true);
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!_capture) return;
    // Use the bundled Inter font for readable offline previews; no font downloads.
    final text = await rootBundle.load(
      'packages/forui/assets/fonts/inter/Inter.ttf',
    );
    for (final family in [
      'Manrope',
      for (final weight in [400, 500, 600, 700, 800]) 'Manrope_$weight',
    ]) {
      await (FontLoader(family)..addFont(Future.value(text))).load();
    }
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final source in ['project', 'my tasks', 'inbox']) {
    testWidgets('$source scheduling waits for explicit confirmation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Planner();
      final existingPlanner = PlannerCubit(repository);
      addTearDown(existingPlanner.close);
      await existingPlanner.initialize();
      sl.registerFactory<PlannerCubit>(() => PlannerCubit(repository));
      addTearDown(() => sl.unregister<PlannerCubit>());
      Widget child;
      if (source == 'my tasks') {
        final data = _Tasks();
        final cubit = MyTasksCubit(repository: data, fieldsStorage: data);
        addTearDown(cubit.close);
        await cubit.configure(
          userId: 'user',
          projects: const [
            ProjectModel(
              id: 'project',
              code: 'ORB',
              name: 'Проект',
              workspaceId: 'w',
              start: null,
              end: null,
            ),
          ],
        );
        child = BlocProvider.value(value: cubit, child: const MyTasksWidget());
      } else if (source == 'inbox') {
        child = const InboxTaskRow(
          task: _inbox,
          isCompleting: false,
          onToggle: null,
        );
      } else {
        child = const TaskCard(task: _task, boardStyle: true);
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: _previewKey,
          child: MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              appBar: AppBar(title: const Text('Мои задачи')),
              body: Padding(padding: const EdgeInsets.all(16), child: child),
              floatingActionButton: Builder(
                builder: (context) => FloatingActionButton(
                  key: const Key('test-open-schedule'),
                  onPressed: () => source == 'inbox'
                      ? showScheduleInboxTask(context, _inbox)
                      : showScheduleProjectTask(context, _task),
                  child: const Icon(Icons.calendar_month),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('planning-selected-task')), findsNothing);
      expect(find.byKey(const Key('planning-schedule-action')), findsNothing);
      expect(repository.writes, 0);
      expect(existingPlanner.state.items, isEmpty);
      await tester.tap(find.byKey(const Key('test-open-schedule')));
      await tester.pumpAndSettle();
      expect(find.text('Добавить в ежедневник'), findsOneWidget);
      expect(repository.writes, 0);
      expect(find.byKey(const Key('schedule-time')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('planner-mode-timed')),
      );
      await tester.tap(find.byKey(const ValueKey('planner-mode-timed')));
      await tester.pumpAndSettle();
      if (source == 'project') await _capturePreview(tester, '02-date-time');
      await tester.tap(find.byKey(const ValueKey('schedule-day-Завтра')));
      await tester.ensureVisible(
        find.byKey(const ValueKey('schedule-duration-60')),
      );
      await tester.tap(find.byKey(const ValueKey('schedule-duration-60')));
      await tester.ensureVisible(find.byKey(const Key('schedule-time')));
      await tester.tap(find.byKey(const Key('schedule-time')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      Navigator.of(
        tester.element(find.byType(TimePickerDialog)),
      ).pop(const TimeOfDay(hour: 14, minute: 30));
      await tester.pumpAndSettle();
      final tomorrow = plannerNow().add(const Duration(days: 1));
      await tester.tap(find.byKey(const Key('schedule-confirm')));
      await tester.pumpAndSettle();
      expect(repository.writes, 1);
      expect(
        existingPlanner.state.items.single.taskId,
        source == 'inbox' ? null : 'task',
      );
      expect(
        existingPlanner.state.items.single.inboxTaskId,
        source == 'inbox' ? 'inbox' : null,
      );
      expect(repository.scheduledAt, plannerInstant(tomorrow, 14, 30));
      expect(repository.duration, 60);
      expect(repository.taskId, source == 'inbox' ? null : 'task');
      expect(repository.inboxId, source == 'inbox' ? 'inbox' : null);
      expect(repository.projectId, source == 'inbox' ? null : 'project');
      expect(find.byKey(const Key('schedule-confirm')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'narrow sheet keeps confirmation visible and preserves choices after failure',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Planner()..fail = true;
      sl.registerFactory<PlannerCubit>(() => PlannerCubit(repository));
      addTearDown(() => sl.unregister<PlannerCubit>());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showScheduleProjectTask(context, _task),
                child: const Text('Планировать'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Планировать'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('planner-mode-timed')),
      );
      await tester.tap(find.byKey(const ValueKey('planner-mode-timed')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('schedule-duration-90')),
      );
      await tester.tap(find.byKey(const ValueKey('schedule-duration-90')));
      await tester.tap(find.byKey(const Key('schedule-confirm')));
      await tester.pumpAndSettle();
      expect(repository.writes, 1);
      expect(
        find.text('Не удалось сохранить. Повторите попытку.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('schedule-duration-90')),
            )
            .selected,
        isTrue,
      );
      repository.fail = false;
      await tester.tap(find.byKey(const Key('schedule-confirm')));
      await tester.pumpAndSettle();
      expect(repository.writes, 2);
      expect(repository.duration, 90);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('load failure can retry and closing never schedules implicitly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Planner()..failLoad = true;
    sl.registerFactory<PlannerCubit>(() => PlannerCubit(repository));
    addTearDown(() => sl.unregister<PlannerCubit>());
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showScheduleProjectTask(context, _task),
              child: const Text('Планировать'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Планировать'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('schedule-confirm')))
          .onPressed,
      isNull,
    );
    repository.failLoad = false;
    await tester.ensureVisible(find.text('Повторить'));
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('schedule-confirm')))
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(find.byTooltip('Закрыть'));
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(repository.writes, 0);
    expect(find.byKey(const Key('schedule-confirm')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'existing task waits for loading and edits its original slot without duplicating',
    (tester) async {
      final day = plannerDate(plannerNow()).add(const Duration(days: 3));
      final scheduled = plannerInstant(day, 11, 15);
      final repository = _Planner()
        ..loadGate = Completer<void>()
        ..items = [
          PlannerItemModel(
            id: 'slot',
            title: _task.title,
            taskId: 'task',
            scheduledAt: scheduled,
            durationMinutes: 45,
          ),
        ];
      sl.registerFactory<PlannerCubit>(() => PlannerCubit(repository));
      addTearDown(() => sl.unregister<PlannerCubit>());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showScheduleProjectTask(context, _task),
                child: const Text('Планировать'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Планировать'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('schedule-confirm')))
            .onPressed,
        isNull,
      );
      repository.loadGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Изменить план'), findsOneWidget);
      expect(find.text('11:15'), findsOneWidget);
      await tester.tap(find.byKey(const Key('schedule-confirm')));
      await tester.pumpAndSettle();
      expect(repository.writes, 1);
      expect(repository.taskId, isNull);
      expect(repository.scheduledAt, scheduled);
      expect(repository.duration, 45);
      expect(tester.takeException(), isNull);
    },
  );
}
