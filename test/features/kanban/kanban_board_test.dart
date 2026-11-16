import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/kanban/data/storage/card_view_storage.dart';
import 'package:jospar/features/kanban/data/models/card_view_settings.dart';
import 'package:flutter/material.dart';
import 'package:jospar/features/tasks/data/models/task_label_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_cubit.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_state.dart';
import 'package:jospar/features/kanban/presentation/widgets/kanban_board.dart';
import 'package:jospar/features/kanban/domain/utils/kanban_utils.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/tasks/data/models/kanban_column_model.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';

const _capture = bool.fromEnvironment('CAPTURE_PLANNER_PREVIEWS');
final _previewKey = GlobalKey();

class _BoardPlanner implements PlannerRepository {
  final added = <String>[];

  @override
  Future<List<PlannerItemModel>> load() async => [];

  @override
  Future<void> addTask({
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {
    added.add('$projectId/$taskId');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _captureDrag(WidgetTester tester, String name) async {
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

class _BoardCubit extends Cubit<KanbanState> implements KanbanCubit {
  _BoardCubit()
    : super(
        const KanbanState(
          projectId: 'p',
          columns: [
            KanbanColumnModel(
              id: 'c',
              name: 'Задачи',
              statusMap: 'TODO',
              order: 0,
            ),
            KanbanColumnModel(
              id: 'done',
              name: 'Готово',
              statusMap: 'DONE',
              order: 1,
            ),
          ],
          tasks: [
            ProjectTaskModel(
              id: 'a',
              title: 'Первая задача',
              fileCount: 2,
              checklistTotal: 4,
              checklistCompleted: 2,
              commentCount: 3,
              epics: [
                TaskEpicModel(
                  id: 'epic',
                  name: 'Архитектура',
                  color: '#26855c',
                ),
              ],
              labels: [
                TaskLabelModel(
                  id: 'label',
                  text: 'Личная метка',
                  isPersonal: true,
                  color: '#6366F1',
                ),
              ],
              projectId: 'p',
              status: 'TODO',
              order: 0,
            ),
            ProjectTaskModel(
              id: 'b',
              title: 'Вторая задача',
              projectId: 'p',
              status: 'TODO',
              order: 1,
            ),
            ProjectTaskModel(
              id: 'c',
              title: 'Третья задача',
              projectId: 'p',
              status: 'TODO',
              order: 2,
            ),
          ],
        ),
      );
  @override
  void setSearch(String value) => emit(state.copyWith(search: value));

  void replaceBoard({
    List<KanbanColumnModel>? columns,
    List<ProjectTaskModel>? tasks,
    Set<String>? busy,
  }) {
    emit(state.copyWith(columns: columns, tasks: tasks, movingTaskIds: busy));
  }

  final moves = <int>[];
  final archived = <String>[];
  @override
  Future<void> archiveTask(ProjectTaskModel task) async {
    archived.add(task.id);
    emit(
      state.copyWith(
        tasks: state.tasks.where((item) => item.id != task.id).toList(),
      ),
    );
  }

  @override
  Future<void> moveTask(
    ProjectTaskModel task,
    String status,
    int position,
  ) async {
    moves.add(position);
    emit(
      state.copyWith(
        tasks: moveKanbanTask(
          tasks: state.tasks,
          taskId: task.id,
          projectId: 'p',
          targetStatus: status,
          targetPosition: position,
        ),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    if (!_capture) return;
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

  for (final narrow in [false, true]) {
    testWidgets(
      'whole-card planner drop is explicit and cancellable (narrow=$narrow)',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        tester.view.physicalSize = narrow
            ? const Size(320, 568)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cubit = _BoardCubit();
        addTearDown(cubit.close);
        final repository = _BoardPlanner();
        sl.registerFactory<PlannerCubit>(() => PlannerCubit(repository));
        addTearDown(() => sl.unregister<PlannerCubit>());
        await tester.pumpWidget(
          RepaintBoundary(
            key: _previewKey,
            child: MaterialApp(
              theme: AppTheme.light,
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(narrow ? 1.6 : 1)),
                child: child!,
              ),
              home: Scaffold(
                appBar: AppBar(title: const Text('Проект')),
                body: BlocProvider<KanbanCubit>.value(
                  value: cubit,
                  child: const KanbanBoard(
                    project: ProjectModel(
                      id: 'p',
                      code: 'P',
                      name: 'Проект',
                      workspaceId: 'w',
                      start: null,
                      end: null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        Future<TestGesture> hold() async {
          final gesture = await tester.startGesture(
            tester.getCenter(find.text('Первая задача')),
          );
          await tester.pump(const Duration(milliseconds: 600));
          expect(find.text('Архивировать'), findsOneWidget);
          expect(find.text('Переместить'), findsOneWidget);
          expect(find.byKey(const Key('kanban-planner-drop')), findsOneWidget);
          expect(
            find.byKey(const Key('planning-schedule-action')),
            findsNothing,
          );
          expect(find.byKey(const ValueKey('task-drag-a')), findsNothing);
          return gesture;
        }

        // Crossing the zone and cancelling a pointer must never open a sheet.
        var gesture = await hold();
        await gesture.moveTo(tester.getCenter(find.text('В ежедневник')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byKey(const Key('schedule-confirm')), findsNothing);
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('schedule-confirm')), findsNothing);
        expect(repository.added, isEmpty);
        expect(cubit.moves, isEmpty);

        // A filtered board still offers actions, while avoiding hidden-row sorting.
        cubit.setSearch('Первая');
        await tester.pumpAndSettle();
        gesture = await hold();
        final drop = tester.getCenter(find.text('В ежедневник'));
        await gesture.moveTo(drop);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
        await _captureDrag(tester, narrow ? 'drag-narrow' : 'drag-planner');
        await gesture.moveTo(const Offset(150, 300));
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('schedule-confirm')), findsNothing);
        expect(cubit.moves, isEmpty);

        // Dropping only asks for date/time. Cancelling leaves the project untouched.
        gesture = await hold();
        await gesture.moveTo(tester.getCenter(find.text('В ежедневник')));
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('schedule-confirm')), findsOneWidget);
        expect(repository.added, isEmpty);
        Navigator.of(
          tester.element(find.byKey(const Key('schedule-confirm'))),
        ).pop();
        await tester.pumpAndSettle();
        expect(repository.added, isEmpty);

        gesture = await hold();
        await gesture.moveTo(tester.getCenter(find.text('В ежедневник')));
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.up();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('schedule-confirm')));
        await tester.pumpAndSettle();
        expect(repository.added, ['p/a']);
        expect(cubit.moves, isEmpty);
        expect(cubit.archived, isEmpty);
        expect(cubit.state.tasks.any((task) => task.id == 'a'), isTrue);
      },
    );
  }

  testWidgets('board shows multiple fixed-width columns on desktop', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = _BoardCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<KanbanCubit>.value(
            value: cubit,
            child: const KanbanBoard(
              project: ProjectModel(
                id: 'p',
                code: 'P',
                name: 'Проект',
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
    expect(find.text('Задачи'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Готово')).dx, lessThan(640));
    await tester.tap(find.byKey(const Key('board-search-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('board-search-field')),
      'Первая',
    );
    expect(cubit.state.search, 'Первая');
    await tester.tap(find.byKey(const Key('board-search-toggle')));
    await tester.pumpAndSettle();
    expect(cubit.state.search, isEmpty);
    expect(find.text('Доска'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card view toggles update cards, persist and reset', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({});
    final storage = CardViewStorage(const FlutterSecureStorage());
    sl.registerSingleton<CardViewStorage>(storage);
    addTearDown(() => sl.unregister<CardViewStorage>());
    final cubit = _BoardCubit();
    addTearDown(cubit.close);
    final semantics = tester.ensureSemantics();
    Widget board() => MaterialApp(
      home: Scaffold(
        body: BlocProvider<KanbanCubit>.value(
          value: cubit,
          child: const KanbanBoard(
            project: ProjectModel(
              id: 'p',
              code: 'P',
              name: 'Проект',
              workspaceId: 'w',
              start: null,
              end: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(board());
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Чек-лист: 2 из 4')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('card-view-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('card-field-id')));
    final checklists = find.byKey(const ValueKey('card-field-checklists'));
    await tester.scrollUntilVisible(
      checklists,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(tester.element(checklists), alignment: 0.4);
    await tester.pumpAndSettle();
    await tester.tap(checklists);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Чек-лист: 2 из 4')), findsNothing);
    final saved = await storage.read();
    expect(saved.shows(CardField.id), isFalse);
    expect(saved.shows(CardField.checklists), isFalse);
    // Recreating the screen reads the same persisted preferences.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(board());
    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('card-view-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сбросить настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Чек-лист: 2 из 4')), findsOneWidget);
    expect((await storage.read()).hidden, isEmpty);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('move sheet updates columns and disables invalid destinations', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = _BoardCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<KanbanCubit>.value(
            value: cubit,
            child: const KanbanBoard(
              project: ProjectModel(
                id: 'p',
                code: 'P',
                name: 'Проект',
                workspaceId: 'w',
                start: null,
                end: null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Another task's operation must not disable this task's move menu.
    cubit.replaceBoard(busy: {'b'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('task-actions-a')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Переместить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('move-to-done')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirm-task-move')))
          .onPressed,
      isNotNull,
    );
    cubit.replaceBoard(
      columns: [cubit.state.columns.first.copyWith(name: 'Новая колонка')],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('move-to-done')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirm-task-move')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('move-to-c')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Перенести в «Новая колонка»'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirm-task-move')))
          .onPressed,
      isNotNull,
    );
    cubit.replaceBoard(
      tasks: cubit.state.tasks.where((task) => task.id != 'a').toList(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Задача больше недоступна'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirm-task-move')))
          .onPressed,
      isNull,
    );
    expect(cubit.moves, isEmpty);
    Navigator.of(tester.element(find.text('Переместить задачу'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('task menu moves to another column', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = _BoardCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<KanbanCubit>.value(
            value: cubit,
            child: const KanbanBoard(
              project: ProjectModel(
                id: 'p',
                code: 'P',
                name: 'Проект',
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
    expect(find.text('Перенести'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('task-actions-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переместить'));
    await tester.pumpAndSettle();
    expect(find.text('Переместить задачу'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('move-to-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Перенести в «Готово»'));
    await tester.pumpAndSettle();
    expect(
      cubit.state.tasks.firstWhere((task) => task.id == 'a').status,
      'DONE',
    );
    expect(cubit.moves, [0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'drag keeps width and opens an animated gap before saving the new position',
    (tester) async {
      final semantics = tester.ensureSemantics();
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = _BoardCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<KanbanCubit>.value(
              value: cubit,
              child: const KanbanBoard(
                project: ProjectModel(
                  id: 'p',
                  code: 'P',
                  name: 'Проект',
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
      expect(find.bySemanticsLabel(RegExp('Вложения: 2')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Обсуждения: 3')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Чек-лист: 2 из 4')), findsOneWidget);
      semantics.dispose();
      expect(find.text('Архитектура'), findsOneWidget);
      expect(find.text('Личная метка'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('task-actions-a')));
      await tester.pumpAndSettle();
      for (final label in [
        'Обложка',
        'Редактировать',
        'Дублировать',
        'Переместить',
        'Поделиться',
        'Копировать ссылку',
        'Перевести задачу',
        'Архивировать',
        'Удалить задачу',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Переместить задачу'), findsNothing);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(cubit.moves, isEmpty);
      expect(cubit.archived, isEmpty);
      final first = find.byKey(const ValueKey('a'));
      final second = find.byKey(const ValueKey('b'));
      final width = tester.getSize(first).width;
      final secondY = tester.getTopLeft(second).dy;
      final start = tester.getCenter(find.byKey(const ValueKey('a')));
      final target = tester.getCenter(find.byKey(const ValueKey('c')));
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Архивировать'), findsOneWidget);
      for (var step = 1; step <= 12; step++) {
        await gesture.moveTo(Offset.lerp(start, target, step / 12)!);
        await tester.pump(const Duration(milliseconds: 32));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSize(first).width, closeTo(width, 0.1));
      expect(tester.getTopLeft(second).dy, lessThan(secondY));
      expect(cubit.moves, isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(cubit.moves, [2]);
      expect(
        cubit.state.tasksFor(cubit.state.columns.first).map((task) => task.id),
        ['b', 'c', 'a'],
      );
      final upStart = tester.getCenter(find.byKey(const ValueKey('a')));
      final upTarget = tester.getTopLeft(second) + const Offset(80, 12);
      final upward = await tester.startGesture(upStart);
      await tester.pump(const Duration(milliseconds: 600));
      for (var step = 1; step <= 12; step++) {
        await upward.moveTo(Offset.lerp(upStart, upTarget, step / 12)!);
        await tester.pump(const Duration(milliseconds: 32));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await upward.moveBy(const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSize(first).width, closeTo(width, 0.1));
      await upward.up();
      await tester.pumpAndSettle();
      expect(cubit.moves, [2, 0]);
      expect(
        cubit.state.tasksFor(cubit.state.columns.first).map((task) => task.id),
        ['a', 'b', 'c'],
      );
      final moveDrag = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('a'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Архивировать'), findsOneWidget);
      await moveDrag.moveTo(tester.getCenter(find.text('Переместить')));
      await tester.pump(const Duration(milliseconds: 200));
      final rightPosition = tester.getCenter(first);
      final moveTarget = tester.getCenter(find.text('Переместить'));
      final archiveTarget = tester.getCenter(find.text('Архивировать'));
      await moveDrag.moveTo(archiveTarget);
      await tester.pump(const Duration(milliseconds: 200));
      final leftPosition = tester.getCenter(first);
      expect(
        rightPosition.dx - leftPosition.dx,
        closeTo(moveTarget.dx - archiveTarget.dx, 1),
      );
      expect(tester.getSize(first).width, closeTo(width, 0.1));
      await moveDrag.moveTo(moveTarget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getCenter(first).dx, closeTo(rightPosition.dx, 1));
      await moveDrag.up();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Переместить задачу'), findsOneWidget);
      expect(cubit.moves, [2, 0]);
      Navigator.of(tester.element(find.text('Переместить задачу'))).pop();
      await tester.pumpAndSettle();
      expect(cubit.moves, [2, 0]);
      final archiveDrag = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('a'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await archiveDrag.moveTo(tester.getCenter(find.text('Архивировать')));
      await tester.pump(const Duration(milliseconds: 200));
      await archiveDrag.up();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(cubit.archived, ['a']);
      expect(find.text('Первая задача'), findsNothing);
      expect(cubit.moves, [2, 0]);
      final changeColumn = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('b'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await changeColumn.moveTo(tester.getCenter(find.text('Переместить')));
      await tester.pump(const Duration(milliseconds: 200));
      await changeColumn.up();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('move-to-done')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Перенести в «Готово»'),
      );
      await tester.pumpAndSettle();
      expect(
        cubit.state.tasks.firstWhere((task) => task.id == 'b').status,
        'DONE',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
