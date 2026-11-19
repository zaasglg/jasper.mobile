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
    required DateTime? scheduledAt,
    DateTime? plannedDate,
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
  final transfers = <(String, String, int)>[];
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
  Future<bool> moveTask(
    ProjectTaskModel task,
    String status,
    int position,
  ) async {
    moves.add(position);
    transfers.add((task.id, status, position));
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
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _showDragBoard(
  WidgetTester tester,
  _BoardCubit cubit, {
  Size size = const Size(1100, 800),
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _previewKey,
      child: MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
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
}

Future<TestGesture> _holdTask(WidgetTester tester, String title) async {
  final gesture = await tester.startGesture(tester.getCenter(find.text(title)));
  await tester.pump(const Duration(milliseconds: 600));
  return gesture;
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

  testWidgets(
    'dropping into an empty column saves its status only after release',
    (tester) async {
      final cubit = _BoardCubit();
      await _showDragBoard(tester, cubit);
      final gesture = await _holdTask(tester, 'Первая задача');
      final target = tester.getRect(
        find.byKey(const ValueKey('kanban-column-done')),
      );
      await gesture.moveTo(Offset(target.center.dx, target.top + 150));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('kanban-insert-done')), findsOneWidget);
      expect(cubit.transfers, isEmpty);
      await _captureDrag(tester, 'drag-between-columns');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(cubit.transfers, [('a', 'DONE', 0)]);
      expect(
        cubit.state.tasks.firstWhere((task) => task.id == 'a').status,
        'DONE',
      );
      expect(find.byKey(const ValueKey('kanban-insert-done')), findsNothing);
      expect(find.text('Переместить задачу'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cross-column insertion uses the visible anchor without reordering filtered tasks',
    (tester) async {
      final cubit = _BoardCubit();
      cubit.replaceBoard(
        tasks: [
          ...cubit.state.tasks,
          const ProjectTaskModel(
            id: 'hidden-before',
            title: 'Скрытое дело',
            projectId: 'p',
            status: 'DONE',
            order: 0,
          ),
          const ProjectTaskModel(
            id: 'visible',
            title: 'Целевая задача',
            projectId: 'p',
            status: 'DONE',
            order: 1,
          ),
          const ProjectTaskModel(
            id: 'hidden-after',
            title: 'Другое дело',
            projectId: 'p',
            status: 'DONE',
            order: 2,
          ),
        ],
      );
      cubit.setSearch('задача');
      await _showDragBoard(tester, cubit);
      final gesture = await _holdTask(tester, 'Первая задача');
      final target = tester.getRect(find.byKey(const ValueKey('visible')));
      await gesture.moveTo(target.topLeft + const Offset(100, 6));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('kanban-insert-done')), findsOneWidget);
      expect(cubit.transfers, isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(cubit.transfers, [('a', 'DONE', 1)]);
      cubit.setSearch('');
      expect(
        cubit.state.tasksFor(cubit.state.columns.last).map((task) => task.id),
        ['hidden-before', 'a', 'visible', 'hidden-after'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancelling or leaving the board never commits a hovered destination',
    (tester) async {
      final cubit = _BoardCubit();
      await _showDragBoard(tester, cubit);
      final target = tester.getRect(
        find.byKey(const ValueKey('kanban-column-done')),
      );
      for (final cancel in [true, false]) {
        final gesture = await _holdTask(tester, 'Первая задача');
        await gesture.moveTo(Offset(target.center.dx, target.top + 150));
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          find.byKey(const ValueKey('kanban-insert-done')),
          findsOneWidget,
        );
        if (cancel) {
          await gesture.cancel();
        } else {
          await gesture.moveTo(const Offset(10, 20));
          await tester.pump();
          expect(
            find.byKey(const ValueKey('kanban-insert-done')),
            findsNothing,
          );
          await gesture.up();
        }
        await tester.pumpAndSettle();
        expect(cubit.transfers, isEmpty);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'phone edge hold crosses multiple pages and supports moving back',
    (tester) async {
      final cubit = _BoardCubit();
      cubit.replaceBoard(
        columns: [
          cubit.state.columns.first,
          const KanbanColumnModel(
            id: 'progress',
            name: 'В работе',
            statusMap: 'IN_PROGRESS',
            order: 1,
          ),
          cubit.state.columns.last.copyWith(order: 2),
        ],
      );
      await _showDragBoard(tester, cubit, size: const Size(390, 844));
      final viewport = tester.getRect(find.byType(PageView));
      Future<void> crossEdge(TestGesture gesture, bool right) async {
        await gesture.moveTo(
          Offset(
            right ? viewport.right - 4 : viewport.left + 4,
            viewport.top + 170,
          ),
        );
        await tester.pump(const Duration(milliseconds: 220));
        await tester.pump(const Duration(milliseconds: 180));
        await gesture.moveTo(Offset(viewport.left + 140, viewport.top + 170));
        await tester.pump(const Duration(milliseconds: 100));
      }

      var gesture = await _holdTask(tester, 'Первая задача');
      await crossEdge(gesture, true);
      expect(
        find.byKey(const ValueKey('kanban-insert-progress')),
        findsOneWidget,
      );
      expect(cubit.transfers, isEmpty);
      await crossEdge(gesture, true);
      expect(find.byKey(const ValueKey('kanban-insert-done')), findsOneWidget);
      expect(cubit.transfers, isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      await _captureDrag(tester, 'drag-between-columns-phone');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(cubit.transfers, [('a', 'DONE', 0)]);
      gesture = await _holdTask(tester, 'Первая задача');
      await crossEdge(gesture, false);
      expect(
        find.byKey(const ValueKey('kanban-insert-progress')),
        findsOneWidget,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(cubit.transfers, [('a', 'DONE', 0), ('a', 'IN_PROGRESS', 0)]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'continuous edge hold switches quickly in both directions and saves only on release',
    (tester) async {
      final cubit = _BoardCubit();
      cubit.replaceBoard(
        columns: [
          cubit.state.columns.first,
          const KanbanColumnModel(
            id: 'progress',
            name: 'В работе',
            statusMap: 'IN_PROGRESS',
            order: 1,
          ),
          const KanbanColumnModel(
            id: 'review',
            name: 'Проверка',
            statusMap: 'REVIEW',
            order: 2,
          ),
          cubit.state.columns.last.copyWith(order: 3),
        ],
      );
      await _showDragBoard(tester, cubit, size: const Size(390, 844));
      final viewport = tester.getRect(find.byType(PageView));
      int currentPage() => tester
          .widget<PageView>(find.byType(PageView))
          .controller!
          .page!
          .round();
      Future<void> finishSwitch(int page) async {
        await tester.pump(const Duration(milliseconds: 200));
        expect(currentPage(), page);
        expect(cubit.transfers, isEmpty);
      }

      var gesture = await _holdTask(tester, 'Первая задача');
      await gesture.moveTo(Offset(viewport.right - 4, viewport.top + 170));
      await tester.pump(const Duration(milliseconds: 219));
      expect(currentPage(), 0);
      await tester.pump(const Duration(milliseconds: 1));
      await finishSwitch(1);
      // Keep the pointer stationary: further columns need no new pointer event.
      await tester.pump(const Duration(milliseconds: 159));
      expect(currentPage(), 1);
      await tester.pump(const Duration(milliseconds: 1));
      await finishSwitch(2);
      await tester.pump(const Duration(milliseconds: 160));
      await finishSwitch(3);
      await tester.pump(const Duration(seconds: 1));
      expect(currentPage(), 3);
      expect(cubit.transfers, isEmpty);
      final destination = tester.getRect(
        find.byKey(const ValueKey('kanban-column-done')),
      );
      await gesture.moveTo(
        Offset(destination.center.dx, destination.top + 150),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(cubit.transfers, [('a', 'DONE', 0)]);

      gesture = await _holdTask(tester, 'Первая задача');
      await gesture.moveTo(Offset(viewport.left + 4, viewport.top + 170));
      for (var page = 2; page >= 0; page--) {
        await tester.pump(Duration(milliseconds: page == 2 ? 220 : 160));
        await tester.pump(const Duration(milliseconds: 200));
        expect(currentPage(), page);
        expect(cubit.transfers.length, 1);
      }
      await gesture.moveTo(
        tester.getTopLeft(find.byKey(const ValueKey('b'))) +
            const Offset(100, 8),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(cubit.transfers, [('a', 'DONE', 0), ('a', 'TODO', 0)]);
      expect(
        cubit.state.tasksFor(cubit.state.columns.first).map((task) => task.id),
        ['a', 'b', 'c'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving an edge and cancelling a drag stop pending and repeated switches',
    (tester) async {
      final cubit = _BoardCubit();
      cubit.replaceBoard(
        columns: [
          cubit.state.columns.first,
          const KanbanColumnModel(
            id: 'progress',
            name: 'В работе',
            statusMap: 'IN_PROGRESS',
            order: 1,
          ),
          cubit.state.columns.last.copyWith(order: 2),
        ],
      );
      await _showDragBoard(tester, cubit, size: const Size(390, 844));
      final view = tester.widget<PageView>(find.byType(PageView));
      final rect = tester.getRect(find.byType(PageView));
      final edge = Offset(rect.right - 4, rect.top + 170);
      final center = Offset(rect.left + 140, rect.top + 170);
      var gesture = await _holdTask(tester, 'Первая задача');
      await gesture.moveTo(edge);
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveTo(center);
      await tester.pump(const Duration(milliseconds: 600));
      expect(view.controller!.page, 0);
      await gesture.moveTo(edge);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.cancel();
      await tester.pump(const Duration(milliseconds: 800));
      expect(view.controller!.page, 0);
      expect(cubit.transfers, isEmpty);

      gesture = await _holdTask(tester, 'Первая задача');
      await gesture.moveTo(edge);
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump(const Duration(milliseconds: 70));
      expect(view.controller!.page, allOf(greaterThan(0), lessThan(1)));
      await gesture.moveTo(center);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 600));
      expect(view.controller!.page, closeTo(1, 0.01));
      expect(cubit.transfers, isEmpty);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(cubit.transfers, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'holding over a long destination scrolls to later insertion positions',
    (tester) async {
      final cubit = _BoardCubit();
      cubit.replaceBoard(
        tasks: [
          ...cubit.state.tasks,
          for (var index = 0; index < 25; index++)
            ProjectTaskModel(
              id: 'destination-$index',
              title: 'Готовая задача $index',
              projectId: 'p',
              status: 'DONE',
              order: index,
            ),
        ],
      );
      await _showDragBoard(tester, cubit, size: const Size(1100, 650));
      final gesture = await _holdTask(tester, 'Первая задача');
      final list = find.descendant(
        of: find.byKey(const ValueKey('kanban-column-done')),
        matching: find.byType(ReorderableList),
      );
      final rect = tester.getRect(list);
      final plannerTop = tester
          .getTopLeft(find.byKey(const Key('kanban-planner-drop')))
          .dy;
      await gesture.moveTo(
        Offset(rect.center.dx, (rect.bottom - 10).clamp(0, plannerTop - 16)),
      );
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(cubit.transfers, isEmpty);
      expect(find.byKey(const ValueKey('kanban-insert-done')), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(cubit.transfers.single.$1, 'a');
      expect(cubit.transfers.single.$2, 'DONE');
      expect(cubit.transfers.single.$3, greaterThan(4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide boards scroll horizontally while holding a card at the edge',
    (tester) async {
      final cubit = _BoardCubit();
      cubit.replaceBoard(
        columns: [
          cubit.state.columns.first,
          const KanbanColumnModel(
            id: 'progress',
            name: 'В работе',
            statusMap: 'IN_PROGRESS',
            order: 1,
          ),
          const KanbanColumnModel(
            id: 'review',
            name: 'Проверка',
            statusMap: 'REVIEW',
            order: 2,
          ),
          cubit.state.columns.last.copyWith(order: 3),
        ],
      );
      await _showDragBoard(tester, cubit, size: const Size(800, 700));
      final gesture = await _holdTask(tester, 'Первая задача');
      await gesture.moveTo(const Offset(778, 310));
      for (var step = 0; step < 2; step++) {
        await tester.pump(Duration(milliseconds: step == 0 ? 220 : 160));
        await tester.pump(const Duration(milliseconds: 200));
      }
      final destination = tester.getRect(
        find.byKey(const ValueKey('kanban-column-done')),
      );
      expect(destination.center.dx, inInclusiveRange(0, 800));
      await gesture.moveTo(
        Offset(destination.center.dx, destination.top + 150),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('kanban-insert-done')), findsOneWidget);
      expect(cubit.transfers, isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(cubit.transfers, [('a', 'DONE', 0)]);
      expect(tester.takeException(), isNull);
    },
  );

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
